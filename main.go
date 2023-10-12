package main

import (
	"os"
	"os/exec"
	"strings"

	"log/slog"
)

func main() {
	programLevel := new(slog.LevelVar)
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: programLevel}))
	slog.SetDefault(logger)

	integrationID := os.Getenv("INTEGRATION_ID")
	logger.Info("ENV info",
		"integrationID", integrationID)

	file1URL := os.Getenv("FILE1_URL")
	logger.Info("ENV info",
		"FILE1_URL", file1URL)
	file2URL := os.Getenv("FILE2_URL")
	logger.Info("ENV info",
		"file2URL", file2URL)

	dfCmd := exec.Command("df", "-h")
	var dfCmdout strings.Builder
	var dfCmdstderr strings.Builder
	dfCmd.Stdout = &dfCmdout
	dfCmd.Stderr = &dfCmdstderr
	if err := dfCmd.Run(); err != nil {
		logger.Error(err.Error(),
			slog.String("error", dfCmdstderr.String()))
	}

	logger.Info("df output",
		slog.String("output", dfCmdout.String()))

	var payload = getIntegrationData(integrationID, file1URL, file2URL) // payload retrieved based on

	for _, fileInput := range payload.PresignedURLs {
		logger.Info("url",
			slog.String("url", fileInput.URL))

		cmd := exec.Command("wget", "-O", fileInput.Filename, fileInput.URL)
		cmd.Dir = "/mnt"
		var out strings.Builder
		var stderr strings.Builder
		cmd.Stdout = &out
		cmd.Stderr = &stderr
		if err := cmd.Run(); err != nil {
			logger.Error(err.Error(),
				slog.String("error", stderr.String()))
		}
		logger.Info("download output",
			slog.String("output", out.String()))

	}

	// run pipeline
	cmd := exec.Command("nextflow", "run", "/service/main.nf", "-ansi-log", "false", "--integration", "integration params go here")
	cmd.Dir = "/mnt"
	var out strings.Builder
	var stderr strings.Builder
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		logger.Error(err.Error(),
			slog.String("error", stderr.String()))
	}

	logger.Info("pipeline output",
		slog.String("output", out.String()))

	logger.Info("Processing complete")
}

type Payload struct {
	PresignedURLs []Files `json:"presignedURLs"`
}

type Files struct {
	Filename string `json:"filename"`
	URL      string `json:"url"`
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
