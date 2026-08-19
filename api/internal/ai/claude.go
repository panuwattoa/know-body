// Package ai wraps Claude's Messages API for KnowBody's food + body-scan analysis.
// When no ANTHROPIC_API_KEY is configured it returns a deterministic stub so the
// full pipeline is exercisable in local dev and tests.
package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const (
	endpoint   = "https://api.anthropic.com/v1/messages"
	apiVersion = "2023-06-01"
)

type Client struct {
	apiKey string
	model  string
	http   *http.Client
}

func New(apiKey, model string) *Client {
	return &Client{
		apiKey: apiKey,
		model:  model,
		http:   &http.Client{Timeout: 60 * time.Second},
	}
}

// Enabled reports whether a real API key is configured.
func (c *Client) Enabled() bool { return c.apiKey != "" }

// Image is a base64-encoded image with its media type (e.g. "image/jpeg").
type Image struct {
	MediaType string
	Base64    string
}

// AnalyzeStructured sends images + instruction and forces the model to call a
// single tool with the given JSON schema, returning that tool's input verbatim.
func (c *Client) AnalyzeStructured(ctx context.Context, instruction string, imgs []Image, toolName string, schema map[string]any) (json.RawMessage, error) {
	content := make([]map[string]any, 0, len(imgs)+1)
	for _, im := range imgs {
		content = append(content, map[string]any{
			"type": "image",
			"source": map[string]any{
				"type":       "base64",
				"media_type": im.MediaType,
				"data":       im.Base64,
			},
		})
	}
	content = append(content, map[string]any{"type": "text", "text": instruction})

	reqBody := map[string]any{
		"model":      c.model,
		"max_tokens": 1024,
		"tools": []map[string]any{{
			"name":         toolName,
			"description":  "Return the structured result for KnowBody.",
			"input_schema": schema,
		}},
		"tool_choice": map[string]any{"type": "tool", "name": toolName},
		"messages":    []map[string]any{{"role": "user", "content": content}},
	}

	buf, _ := json.Marshal(reqBody)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("x-api-key", c.apiKey)
	req.Header.Set("anthropic-version", apiVersion)
	req.Header.Set("content-type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("anthropic %d: %s", resp.StatusCode, body)
	}

	var parsed struct {
		Content []struct {
			Type  string          `json:"type"`
			Name  string          `json:"name"`
			Input json.RawMessage `json:"input"`
		} `json:"content"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, err
	}
	for _, block := range parsed.Content {
		if block.Type == "tool_use" && block.Name == toolName {
			return block.Input, nil
		}
	}
	return nil, fmt.Errorf("no tool_use block returned")
}
