package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"strings"

	"log/slog"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/lambdacontext"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func ServiceHandler(ctx context.Context, request events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	programLevel := new(slog.LevelVar)
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: programLevel}))
	slog.SetDefault(logger)

	if lc, ok := lambdacontext.FromContext(ctx); ok {
		logger.With("awsRequestID", lc.AwsRequestID)
	}

	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("could not load AWS config %v", err)
	}

	inputFiles := []string{"20230531_counts_renamed_with_meta.csv",
		"20230531_IH_gating_AALC_IHCV.csv",
		"main.R"}
	s3Client := s3.NewFromConfig(cfg)
	pipelineStorage := NewS3(s3Client, "data-analysis-pipelines")

	for _, filename := range inputFiles {
		result, err := pipelineStorage.Get(ctx, &filename)
		if err != nil {
			logger.ErrorContext(ctx, err.Error())
			os.Exit(1)
		}
		defer result.Body.Close()
		fileContents, err := io.ReadAll(result.Body)
		if err != nil {
			logger.ErrorContext(ctx, err.Error())
		}

		err = os.WriteFile(fmt.Sprintf("/tmp/%s", filename), fileContents, 0755)
		if err != nil {
			logger.ErrorContext(ctx, err.Error())
		}
	}

	// run pipeline
	cmd := exec.Command("Rscript", "/tmp/main.R")
	var out strings.Builder
	var stderr strings.Builder
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		logger.Error(err.Error(),
			slog.String("error", stderr.String()))
	}

	outputFilename := "IH_report_CyTOF_53.T1_Normalized.fcs.pdf"
	outputFile := fmt.Sprintf("/tmp/%s", outputFilename)
	bytesRead, err := os.ReadFile(outputFile)
	if err != nil {
		logger.Error(err.Error())
	}
	_, err = pipelineStorage.Put(ctx,
		fmt.Sprintf("out/%s", outputFilename),
		bytesRead)
	if err != nil {
		logger.Error(err.Error())
	}

	response := events.APIGatewayV2HTTPResponse{
		StatusCode: 200,
		Body:       "ServiceHandler",
	}
	return response, nil
}

func main() {
	lambda.Start(ServiceHandler)
}

type StorageService interface {
	Get(context.Context, *string) (*s3.GetObjectOutput, error)
	Put(context.Context, string, []byte) (*s3.PutObjectOutput, error)
}

type SimpleStorageService struct {
	Client     *s3.Client
	BucketName string
}

func NewS3(client *s3.Client, bucket string) StorageService {
	return &SimpleStorageService{client, bucket}
}

func (s *SimpleStorageService) Get(ctx context.Context, filename *string) (*s3.GetObjectOutput, error) {
	output, err := s.Client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.BucketName),
		Key:    filename,
	})
	if err != nil {
		return nil, err
	}

	return output, nil
}

func (s *SimpleStorageService) Put(ctx context.Context, filename string, bytesRead []byte) (*s3.PutObjectOutput, error) {
	output, err := s.Client.PutObject(ctx, &s3.PutObjectInput{
		Bucket: aws.String(s.BucketName),
		Key:    &filename,
		Body:   bytes.NewReader(bytesRead),
	})
	if err != nil {
		return nil, err
	}

	return output, nil
}
