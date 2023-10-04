package main

import (
	"context"
	"os"
	"os/exec"
	"strings"

	"log/slog"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/lambdacontext"
)

func ServiceHandler(ctx context.Context, request events.APIGatewayV2HTTPRequest) (events.APIGatewayV2HTTPResponse, error) {
	programLevel := new(slog.LevelVar)
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: programLevel}))
	slog.SetDefault(logger)

	if lc, ok := lambdacontext.FromContext(ctx); ok {
		logger.With("awsRequestID", lc.AwsRequestID)
	}

	// run pipeline
	cmd := exec.Command("Rscript", "/service/main.R", "/service/data", "/service/data")
	cmd.Dir = "/tmp"
	var out strings.Builder
	var stderr strings.Builder
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		logger.Error(err.Error(),
			slog.String("error", stderr.String()))
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
