package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"

	"log/slog"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ecs"
	"github.com/aws/aws-sdk-go-v2/service/ecs/types"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/google/uuid"
)

func main() {
	programLevel := new(slog.LevelVar)
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: programLevel}))
	slog.SetDefault(logger)

	integrationID := os.Getenv("INTEGRATION_ID")
	baseDir := os.Getenv("BASE_DIR")
	if integrationID == "" {
		id := uuid.New()
		integrationID = id.String()
	}
	if baseDir == "" {
		baseDir = "/mnt/efs"
	}

	logger.Info(integrationID)
	// create subdirectories
	err := os.Chdir(baseDir)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}

	err = os.MkdirAll(fmt.Sprintf("input/%s", integrationID), 0755)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
	err = os.MkdirAll("output", 0777)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
	err = os.Chown("output", 1000, 1000)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
	err = os.MkdirAll(fmt.Sprintf("output/%s", integrationID), 0777)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
	err = os.Chown(fmt.Sprintf("output/%s", integrationID), 1000, 1000)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}

	// get input files
	sessionToken := os.Getenv("SESSION_TOKEN")
	apiHost := os.Getenv("PENNSIEVE_API_HOST")
	packages := getPackageIds()
	manifest, err := getPresignedUrls(apiHost, packages, sessionToken)
	if err != nil {
		log.Fatalln(err)
	}
	fmt.Println(string(manifest))
	var payload Manifest
	if err := json.Unmarshal(manifest, &payload); err != nil {
		logger.ErrorContext(context.Background(), err.Error())
	}
	fmt.Println(payload.Data)
	for _, d := range payload.Data {
		cmd := exec.Command("wget", "-O", d.FileName, d.Url)
		cmd.Dir = fmt.Sprintf("input/%s", integrationID)
		var out strings.Builder
		var stderr strings.Builder
		cmd.Stdout = &out
		cmd.Stderr = &stderr
		if err := cmd.Run(); err != nil {
			logger.Error(err.Error(),
				slog.String("error", stderr.String()))
		}
	}

	inputFileName := fmt.Sprintf("input/%s/test.txt", integrationID)
	// process input file
	outputFileName := fmt.Sprintf("output/%s/test.txt", integrationID)
	input, err := os.ReadFile(inputFileName)
	if err != nil {
		log.Fatalln(err)
	}

	lines := strings.Split(string(input), "\n")

	for i, line := range lines {
		if strings.Contains(line, "YEH") {
			lines[i] = "LOL"
		}
	}
	output := strings.Join(lines, "\n")

	// write contents to output dir
	err = os.WriteFile(outputFileName, []byte(output), 0644)
	if err != nil {
		log.Fatalln(err)
	}

	cmd := exec.Command("cat", inputFileName)
	cmd.Dir = baseDir
	var out strings.Builder
	var stderr strings.Builder
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		log.Println(err.Error())
		log.Println(stderr.String())
	}
	log.Println("cat output", out.String())

	// invoke Post processing
	// cfg, err := config.LoadDefaultConfig(context.Background())
	// if err != nil {
	// 	log.Fatalf("LoadDefaultConfig: %v\n", err)
	// }
	// client := lambda.NewFromConfig(cfg)
	// _, err = client.Invoke(context.Background(),
	// 	&lambda.InvokeInput{
	// 		FunctionName: aws.String(os.Getenv("POST_PROCESSOR_INVOKE_ARN")),
	// 	})

	// if err != nil {
	// 	log.Println(err.Error())
	// }
	TaskDefinitionArn := os.Getenv("TASK_DEFINITION_NAME_POST")
	subIdStr := os.Getenv("SUBNET_IDS")
	SubNetIds := strings.Split(subIdStr, ",")
	cluster := os.Getenv("CLUSTER_NAME")
	SecurityGroup := os.Getenv("SECURITY_GROUP_ID")
	TaskDefContainerName := os.Getenv("CONTAINER_NAME_POST")
	apiKey := os.Getenv("PENNSIEVE_API_KEY")
	apiSecret := os.Getenv("PENNSIEVE_API_SECRET")

	agentHome := os.Getenv("PENNSIEVE_AGENT_HOME")

	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("LoadDefaultConfig: %v\n", err)
	}

	client := ecs.NewFromConfig(cfg)
	log.Println("Initiating post processing Task.")
	apiKeyKey := "PENNSIEVE_API_KEY"
	apiSecretKey := "PENNSIEVE_API_SECRET"
	apihostKey := "PENNSIEVE_API_HOST"
	agentHomeKey := "PENNSIEVE_AGENT_HOME"
	integrationIDKey := "INTEGRATION_ID"

	runTaskIn := &ecs.RunTaskInput{
		TaskDefinition: aws.String(TaskDefinitionArn),
		Cluster:        aws.String(cluster),
		NetworkConfiguration: &types.NetworkConfiguration{
			AwsvpcConfiguration: &types.AwsVpcConfiguration{
				Subnets:        SubNetIds,
				SecurityGroups: []string{SecurityGroup},
				AssignPublicIp: types.AssignPublicIpEnabled,
			},
		},
		Overrides: &types.TaskOverride{
			ContainerOverrides: []types.ContainerOverride{
				{
					Name: &TaskDefContainerName,
					Environment: []types.KeyValuePair{
						{
							Name:  &apiKeyKey,
							Value: &apiKey,
						},
						{
							Name:  &apiSecretKey,
							Value: &apiSecret,
						},
						{
							Name:  &apihostKey,
							Value: &apiHost,
						},
						{
							Name:  &agentHomeKey,
							Value: &agentHome,
						},
						{
							Name:  &integrationIDKey,
							Value: &integrationID,
						},
					},
				},
			},
		},
		LaunchType: types.LaunchTypeFargate,
	}

	_, err = client.RunTask(context.Background(), runTaskIn)
	if err != nil {
		log.Fatalf("error running task: %v\n", err)
	}

	logger.Info("Processing complete")
}

func getPackageIds() Packages {
	return Packages{
		NodeIds: []string{"N:package:10024142-6f36-4104-b311-d281cb0cadcd"},
	}
}

type Packages struct {
	NodeIds []string `json:"nodeIds"`
}

type Manifest struct {
	Data []ManifestData `json:"data"`
}

type ManifestData struct {
	NodeId   string   `json:"nodeId"`
	FileName string   `json:"fileName"`
	Path     []string `json:"path"`
	Url      string   `json:"url"`
}

func getPresignedUrls(apiHost string, packages Packages, sessionToken string) ([]byte, error) {
	url := fmt.Sprintf("%s/packages/download-manifest?api_key=%s", apiHost, sessionToken)
	b, err := json.Marshal(packages)
	if err != nil {
		return nil, err
	}
	fmt.Println(string(b))

	payload := strings.NewReader(string(b))

	req, _ := http.NewRequest("POST", url, payload)

	req.Header.Add("accept", "*/*")
	req.Header.Add("content-type", "application/json")

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}

	defer res.Body.Close()
	body, _ := io.ReadAll(res.Body)

	return body, nil
}
