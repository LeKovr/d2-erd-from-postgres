package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"text/template"

	"github.com/georgysavva/scany/v2/pgxscan"
	"github.com/jackc/pgx/v5"
)

// MetaData holds query.sql result
type MetaData struct {
	TableName        string
	PrimaryKey       string
	Columns          []map[string]any
	ForeignRelations []map[string]string
}

func main() {
	conn, err := pgx.Connect(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to connect to database: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close(context.Background())

	sql, err := ioutil.ReadFile("query.sql")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to read query.sql: %v\n", err)
		os.Exit(1)
	}
	var data []*MetaData
	schema := "public"
	err = pgxscan.Select(context.Background(), conn, &data, string(sql), schema)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Query error: %v\n", err)
		os.Exit(1)
	}
	temp := template.Must(template.ParseFiles("template.gotmpl"))
	err = temp.Execute(os.Stdout, data)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to execute template: %v\n", err)
		os.Exit(1)
	}
}
