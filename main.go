package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
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

	logger.InfoContext(ctx, "request info",
		"payload", request.Body)

	var payload Payload
	if err := json.Unmarshal([]byte(request.Body), &payload); err != nil {
		logger.ErrorContext(ctx, err.Error())
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       "ServiceHandler",
		}, errors.New("error unmarshaling")

	}

	for _, fileInput := range payload.PresignedURLs {
		logger.Info("url",
			slog.String("url", fileInput.URL))

		cmd := exec.Command("wget", "-O", fileInput.Filename, fileInput.URL)
		cmd.Dir = "/tmp"
		var out strings.Builder
		var stderr strings.Builder
		cmd.Stdout = &out
		cmd.Stderr = &stderr
		if err := cmd.Run(); err != nil {
			logger.Error(err.Error(),
				slog.String("error", stderr.String()))
		}
	}

	// run pipeline
	cmd := exec.Command("Rscript", "/service/main.R")
	cmd.Dir = "/tmp"
	var out strings.Builder
	var stderr strings.Builder
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		logger.Error(err.Error(),
			slog.String("error", stderr.String()))
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       "ServiceHandler",
		}, nil
	}

	// put file on AWS
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("could not load AWS config %v", err)
	}

	s3Client := s3.NewFromConfig(cfg)
	pipelineStorage := NewS3(s3Client, "data-analysis-pipelines")
	outputFilename := "IH_report_CyTOF_53.T1_Normalized.fcs.pdf"
	outputFile := fmt.Sprintf("/tmp/%s", outputFilename)
	bytesRead, err := os.ReadFile(outputFile)
	if err != nil {
		logger.Error(err.Error())
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       "ServiceHandler",
		}, nil
	}
	_, err = pipelineStorage.Put(ctx,
		fmt.Sprintf("output/%s", outputFilename),
		bytesRead)
	if err != nil {
		logger.Error(err.Error())
		return events.APIGatewayV2HTTPResponse{
			StatusCode: 500,
			Body:       "ServiceHandler",
		}, nil
	}

	response := events.APIGatewayV2HTTPResponse{
		StatusCode: 200,
		Body:       "ServiceHandler",
	}
	return response, nil
}

type Payload struct {
	PresignedURLs []Files `json:"presignedURLs"`
	RunType       string  `json:"runType"`
}

type Files struct {
	Filename string `json:"filename"`
	URL      string `json:"url"`
}

func main() {
	lambda.Start(ServiceHandler)
}

type StorageService interface {
	Put(context.Context, string, []byte) (*s3.PutObjectOutput, error)
}

type SimpleStorageService struct {
	Client     *s3.Client
	BucketName string
}

func NewS3(client *s3.Client, bucket string) StorageService {
	return &SimpleStorageService{client, bucket}
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
