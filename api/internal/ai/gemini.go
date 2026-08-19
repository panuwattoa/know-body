package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// GeminiClient calls Google's Generative Language API (free tier via AI Studio key).
// It implements the same shape as the Claude client, using responseSchema for
// structured JSON output. Get a free key at https://aistudio.google.com/apikey.
type GeminiClient struct {
	apiKey string
	model  string
	http   *http.Client
}

func NewGemini(apiKey, model string) *GeminiClient {
	if model == "" {
		model = "gemini-2.0-flash"
	}
	return &GeminiClient{apiKey: apiKey, model: model, http: &http.Client{Timeout: 60 * time.Second}}}

func (c *GeminiClient) Enabled() bool { return c.apiKey != "" }

func (c *GeminiClient) AnalyzeStructured(ctx context.Context, instruction string, imgs []Image, _ string, schema map[string]any) (json.RawMessage, error) {
	parts := make([]map[string]any, 0, len(imgs)+1)
	for _, im := range imgs {
		parts = append(parts, map[string]any{
			"inline_data": map[string]any{"mime_type": im.MediaType, "data": im.Base64},
		})
	}
	parts = append(parts, map[string]any{"text": instruction})

	reqBody := map[string]any{
		"contents": []map[string]any{{"role": "user", "parts": parts}},
		"generationConfig": map[string]any{
			"responseMimeType": "application/json",
			"responseSchema":   toGeminiSchema(schema),
			"temperature":      0.2,
			// Programs are large; without a high cap the JSON gets truncated → invalid.
			"maxOutputTokens": 8192,
		},
	}
	buf, _ := json.Marshal(reqBody)

	url := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent", c.model)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("content-type", "application/json")
	req.Header.Set("x-goog-api-key", c.apiKey)

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("gemini %d: %s", resp.StatusCode, body)
	}

	var parsed struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
			FinishReason string `json:"finishReason"`
		} `json:"candidates"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, err
	}
	if len(parsed.Candidates) == 0 {
		return nil, fmt.Errorf("gemini: no candidates: %s", body)
	}
	cand := parsed.Candidates[0]
	if cand.FinishReason != "" && cand.FinishReason != "STOP" {
		// e.g. MAX_TOKENS / SAFETY — the JSON is likely partial/invalid.
		return nil, fmt.Errorf("gemini finishReason=%s", cand.FinishReason)
	}
	// Join all parts (the model may split a long JSON across parts).
	var sb strings.Builder
	for _, p := range cand.Content.Parts {
		sb.WriteString(p.Text)
	}
	if sb.Len() == 0 {
		return nil, fmt.Errorf("gemini: empty response")
	}
	return json.RawMessage(sb.String()), nil
}

// toGeminiSchema converts our JSON-Schema-ish map to Gemini's schema dialect,
// mainly uppercasing `type` values (STRING/OBJECT/ARRAY/NUMBER/…).
func toGeminiSchema(in map[string]any) map[string]any {
	out := make(map[string]any, len(in))
	for k, v := range in {
		switch k {
		case "type":
			if s, ok := v.(string); ok {
				out["type"] = strings.ToUpper(s)
			}
		case "properties":
			if props, ok := v.(map[string]any); ok {
				np := make(map[string]any, len(props))
				for pk, pv := range props {
					if pm, ok := pv.(map[string]any); ok {
						np[pk] = toGeminiSchema(pm)
					}
				}
				out["properties"] = np
			}
		case "items":
			if im, ok := v.(map[string]any); ok {
				out["items"] = toGeminiSchema(im)
			}
		default:
			out[k] = v // enum, required, description pass through
		}
	}
	return out
}
