package main

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	"log/slog"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func main() {
	programLevel := new(slog.LevelVar)
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: programLevel}))
	slog.SetDefault(logger)

	ctx := context.Background()

	integrationID := os.Getenv("INTEGRATION_ID")
	logger.Info("ENV info",
		"integrationID", integrationID)

	file1URL := os.Getenv("FILE1_URL")
	logger.Info("ENV info",
		"FILE1_URL", file1URL)
	file2URL := os.Getenv("FILE2_URL")
	logger.Info("ENV info",
		"file2URL", file2URL)

	var payload = getIntegrationData(integrationID, file1URL, file2URL) // payload retrieved based on

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
	}
	_, err = pipelineStorage.Put(ctx,
		fmt.Sprintf("output/%s", outputFilename),
		bytesRead)
	if err != nil {
		logger.Error(err.Error())
	}

	logger.Info("Processing complete")
}

type Payload struct {
	PresignedURLs []Files `json:"presignedURLs"`
}

type Files struct {
	Filename string `json:"filename"`
	URL      string `json:"url"`
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

func getIntegrationData(integrationID string, file1 string, file2 string) Payload {
	files := []Files{
		{
			Filename: "20230531_IH_gating_AALC_IHCV.csv",
			URL:      file1,
		},
		{
			Filename: "20230531_counts_renamed_with_meta.csv",
			URL:      file2,
		},
	}
	return Payload{
		PresignedURLs: files,
	}
}
