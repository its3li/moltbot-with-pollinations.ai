---
summary: "Use Pollinations AI API to access GLM models in Moltbot"
read_when:
  - You want to use Pollinations AI's GLM model in Moltbot
  - You need to configure Pollinations AI authentication
---
# Pollinations AI

Pollinations AI provides access to **GLM models** through an OpenAI-compatible API. It offers a simple way to integrate GLM models into Moltbot with minimal configuration.

## CLI setup

```bash
moltbot onboard --auth-choice apiKey --token-provider pollinations --token "$POLLINATIONS_API_KEY"
```

## Config snippet

```json5
{
  env: { POLLINATIONS_API_KEY: "your-api-key-here" },
  agents: {
    defaults: {
      model: { primary: "pollinations/glm" }
    }
  }
}
```

## Notes

- Model refs are `pollinations/glm`.
- Pollinations AI uses OpenAI-compatible API format.
- Set `POLLINATIONS_API_KEY` environment variable with your API key.
- The GLM model supports text input only.
- Current context window is 128k tokens with 8k max output tokens.