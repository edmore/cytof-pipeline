package main

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"os/exec"
	"strings"
)

type ServiceHandler struct{}

func (dh *ServiceHandler) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	_ = req.Context()
	body := req.Body
	defer body.Close()
	rw.WriteHeader(http.StatusAccepted)
	rw.Header().Set("Content-Type", "application/json")
	var b bytes.Buffer
	io.Copy(&b, body)
	log.Print(b.String())

	// run pipeline
	cmd := exec.Command("nextflow", "run", "/tmp/main.nf")
	var out strings.Builder
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		log.Fatalf(err.Error())
	}

	rw.Write([]byte(out.String()))
}

func NewHandler() http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/run", &ServiceHandler{})
	return mux
}

func main() {
	fmt.Println("cytof-pipeline service")
	srv := &http.Server{
		Addr:    ":8081",
		Handler: NewHandler(),
	}

	log.Println("cytof-pipeline service ...")
	log.Fatal(srv.ListenAndServe())
}
