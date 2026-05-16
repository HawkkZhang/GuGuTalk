using System.Net.Http.Json;
using System.Text.Json;
using GuGuTalk.Core.Models;
using Serilog;

namespace GuGuTalk.Core.Services;

public sealed class LLMClient
{
    private static readonly ILogger Logger = Log.ForContext<LLMClient>();
    private readonly HttpClient _httpClient;

    public LLMClient()
    {
        _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
    }

    public async Task<string> CompleteAsync(string system, string user, LLMProviderConfig config)
    {
        if (config.Endpoint.Contains("anthropic", StringComparison.OrdinalIgnoreCase))
            return await AnthropicCompleteAsync(system, user, config);

        return await OpenAICompleteAsync(system, user, config);
    }

    private async Task<string> OpenAICompleteAsync(string system, string user, LLMProviderConfig config)
    {
        string endpoint = config.Endpoint.TrimEnd('/') + "/v1/chat/completions";

        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint);
        request.Headers.Add("Authorization", $"Bearer {config.ApiKey}");

        var body = new
        {
            model = config.Model,
            messages = new object[]
            {
                new { role = "system", content = system },
                new { role = "user", content = user }
            },
            temperature = 0.3
        };

        request.Content = JsonContent.Create(body);
        var response = await _httpClient.SendAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            string errorBody = await response.Content.ReadAsStringAsync();
            Logger.Error("OpenAI API error. status={Status} body={Body}", (int)response.StatusCode, errorBody);
            throw new InvalidOperationException($"LLM 请求失败：HTTP {(int)response.StatusCode}");
        }

        using var doc = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync());
        var root = doc.RootElement;
        var choices = root.GetProperty("choices");
        var content = choices[0].GetProperty("message").GetProperty("content").GetString();
        return content?.Trim() ?? "";
    }

    private async Task<string> AnthropicCompleteAsync(string system, string user, LLMProviderConfig config)
    {
        string endpoint = config.Endpoint.TrimEnd('/') + "/v1/messages";

        using var request = new HttpRequestMessage(HttpMethod.Post, endpoint);
        request.Headers.Add("x-api-key", config.ApiKey);
        request.Headers.Add("anthropic-version", "2023-06-01");

        var body = new
        {
            model = config.Model,
            max_tokens = 4096,
            system,
            messages = new object[]
            {
                new { role = "user", content = user }
            }
        };

        request.Content = JsonContent.Create(body);
        var response = await _httpClient.SendAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            string errorBody = await response.Content.ReadAsStringAsync();
            Logger.Error("Anthropic API error. status={Status} body={Body}", (int)response.StatusCode, errorBody);
            throw new InvalidOperationException($"LLM 请求失败：HTTP {(int)response.StatusCode}");
        }

        using var doc = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync());
        var root = doc.RootElement;
        var content = root.GetProperty("content");
        var text = content[0].GetProperty("text").GetString();
        return text?.Trim() ?? "";
    }
}
