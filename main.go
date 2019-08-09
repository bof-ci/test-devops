package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
)

var address = flag.String("address", "127.0.0.1", "server address")
var port = flag.String("port", "8800", "server port")
var caFile = flag.String("ca-file", "", "ca file")
var certFile = flag.String("cert-file", "", "cert file")
var keyFile = flag.String("key-file", "", "key file")

// Office contains Ljubljana and London addresses.
type Office struct {
	Hostname string `json:"hostname"`
	Name     string `json:"name"`
	Email    string `json:"email"`
	Project  string `json:"project"`
	IP       string `json:"ip"`
}

func getLocalIP() string {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return ""
	}
	for _, address := range addrs {
		if ipnet, ok := address.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				return ipnet.IP.String()
			}
		}
	}
	return ""
}

func indexHnd(w http.ResponseWriter, r *http.Request) {
	hostname, err := os.Hostname()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}

	var email string
	if r.TLS != nil {
		email = r.TLS.PeerCertificates[0].Subject.CommonName
	}

	office := &Office{
		Hostname: hostname,
		Name:     r.Header.Get("X-NAME"),
		Email:    email,
		Project:  os.Getenv("COMPOSE_PROJECT_NAME"),
		IP:       getLocalIP(),
	}

	js, err := json.Marshal(office)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	//w.Header().Set("Content-Type", "application/json")
	w.Write(js)
}

func main() {
	flag.Parse()

	fmt.Println("BoF Test App")
	fmt.Println("https://www.businessoffashion.com")
	fmt.Printf("\nStarting server at: http://%s:%s/ \n", *address, *port)

	var isTLS bool
	if *caFile != "" && *certFile != "" && *keyFile != "" {
		isTLS = true
	}

	var server *http.Server
	{
		mux := http.NewServeMux()
		mux.HandleFunc("/", indexHnd)

		var tlsConfig *tls.Config
		if isTLS {
			b, err := ioutil.ReadFile(*caFile)
			if err != nil {
				panic(err.Error())
			}
			clientCertPool := x509.NewCertPool()
			if !clientCertPool.AppendCertsFromPEM(b) {
				panic("failed to parse ca certificate")
			}

			tlsConfig = &tls.Config{
				// Reject any TLS certificate that cannot be validated
				ClientAuth: tls.RequireAndVerifyClientCert,
				// Ensure that we only use our "CA" to validate certificates
				ClientCAs: clientCertPool,
			}

			tlsConfig.BuildNameToCertificate()
		}

		server = &http.Server{Addr: *address + ":" + *port, Handler: mux, TLSConfig: tlsConfig}
	}

	go func() {
		c := make(chan os.Signal, 1)
		signal.Notify(c, os.Interrupt, syscall.SIGUSR1, syscall.SIGTERM)
		select {
		case sig := <-c:
			var err error

			fmt.Printf("\nReceived signal: %s\n\n", sig)
			if sig == syscall.SIGUSR1 {
				fmt.Println("Gracefully shutting down server...")
				err = server.Shutdown(nil)
			} else {
				fmt.Println("Terminating server...")
				err = server.Close()
			}
			if err != nil {
				fmt.Println(err.Error())
			}
		}
	}()

	{
		var err error
		if *caFile != "" && *certFile != "" && *keyFile != "" {
			err = server.ListenAndServeTLS(*certFile, *keyFile)
		} else {
			err = server.ListenAndServe()
		}
		if err != nil {
			fmt.Println(err.Error())
		}
	}
}
