# Apple Foundation Models

Apple's Foundation Models framework allows developers to use an on-device large language model to create intelligent app features. It enables various tasks like text generation, summarization, and creating in-game dialogue.

## Key Features

- **On-device:** Runs directly on the user's device, ensuring privacy and efficiency.
- **Guided Generation:** Generate instances of custom Swift data structures.
- **Tool Calling:** Create custom tools that the model can call to perform specific actions or retrieve information.

## Requirements

- End-users must have Apple Intelligence activated on their supported devices.

## Usage

### 1. LanguageModelSession

The primary interaction with the language model is managed through a `LanguageModelSession`, which represents an ongoing conversation.

- `Prompt`: The user's input.
- `Instructions`: Guide the model's behavior for the session.
- `Transcript`: Captures the entire interaction, including inputs and outputs.

### 2. Entry Point

The main entry point to the model is the `SystemLanguageModel` class.

### 3. Guided Generation

By using the `@Generable` macro with your custom Swift data structures, you can instruct the model to generate output that is a valid instance of your type. This ensures that the model's response is structured and can be directly used in your app's logic.

**Example:**

```swift
@Generable
struct Book {
  var title: String
  var author: String
}
```

### 4. Tool Calling

You can define custom tools by conforming to the `Tool` protocol. This allows the model to call your app's code to perform specific tasks, such as accessing a database, calling a web service, or interacting with other parts of your application, thereby extending the model's capabilities.

**Example:**

```swift
struct BookLookupTool: Tool {
  func run() async throws -> String {
    // implementation to look up a book
  }
}
```

### 5. GenerationOptions

Developers can also provide `GenerationOptions` to control aspects of the model's response generation.

## Complete Usage Examples

### Basic Text Generation

```swift
import FoundationModels

func generateText() async {
  let session = LanguageModelSession()
  let prompt = "Write a short story about a robot learning to paint."
  
  do {
    let response = try await session.respond(to: prompt)
    print(response.content)
  } catch {
    print("Error: \(error)")
  }
}
```

### Structured Data Generation

```swift
import FoundationModels

@Generable
struct Recipe {
  @Guide("The name of the recipe.")
  var name: String
  
  @Guide("List of ingredients needed.")
  var ingredients: [String]
  
  @Guide("Step-by-step cooking instructions.")
  var instructions: String
}

func generateRecipe() async {
  let session = LanguageModelSession()
  let prompt = "Create a simple pasta recipe."
  
  do {
    let recipe: Recipe = try await session.generate(from: prompt)
    print("Recipe: \(recipe.name)")
    print("Ingredients: \(recipe.ingredients.joined(separator: ", "))")
    print("Instructions: \(recipe.instructions)")
  } catch {
    print("Error generating recipe: \(error)")
  }
}
```

### Streaming Responses

```swift
import FoundationModels

func streamResponse() async {
  let session = LanguageModelSession()
  let prompt = "Tell me about the history of artificial intelligence."
  
  do {
    let stream = session.streamResponse(from: prompt)
    var fullResponse = ""
    
    for try await partialResponse in stream {
      fullResponse += partialResponse.content
      print("Current response: \(fullResponse)")
    }
  } catch {
    print("Error streaming response: \(error)")
  }
}
```

### Model Availability Check

```swift
import FoundationModels

func checkModelAvailability() {
  let model = SystemLanguageModel.default
  
  if model.isAvailable {
    print("Foundation Model is available on this device")
  } else {
    print("Foundation Model is not available")
    print("Availability status: \(model.availability)")
  }
}
```

### Advanced: Custom Tools

```swift
import FoundationModels

struct WeatherTool: Tool {
  var name = "get_weather"
  var description = "Get current weather for a location"
  
  struct Parameters: Codable {
    let location: String
  }
  
  func run(with parameters: Parameters) async throws -> String {
    // Simulate weather API call
    return "The weather in \(parameters.location) is sunny, 22°C"
  }
}

func useCustomTool() async {
  let session = LanguageModelSession()
  let weatherTool = WeatherTool()
  
  // Add tool to session
  session.addTool(weatherTool)
  
  let prompt = "What's the weather like in Tokyo?"
  
  do {
    let response = try await session.respond(to: prompt)
    print(response.content)
  } catch {
    print("Error: \(error)")
  }
}
```

### Generation with Instructions

```swift
import FoundationModels

func generateWithInstructions() async {
  let instructions = "You are a helpful cooking assistant. Always provide recipes with exact measurements and cooking times."
  let session = LanguageModelSession(instructions: instructions)
  
  let prompt = "How do I make chocolate chip cookies?"
  
  do {
    let response = try await session.respond(to: prompt)
    print(response.content)
  } catch {
    print("Error: \(error)")
  }
}
```

## Device Requirements

- **iPhone**: iPhone 15 Pro/Pro Max (A17 Pro chip) and newer
- **iPad**: Models with M1 chip or later  
- **Mac**: Apple silicon (M-series chips)
- **OS**: iOS 18.1+, iPadOS 18.1+, macOS 15.1+
- **Development**: Xcode 16+

## Performance Considerations

- **Memory**: Uses quantization (2-bit/4-bit mixed configuration)
- **Speed**: ~30 tokens/second on iPhone 15 Pro
- **Power**: On-demand Neural Engine activation
- **Privacy**: All processing happens on-device

## Best Practices

1. **Check Availability**: Always verify model availability before use
2. **Use @Generable**: Leverage structured generation for reliable data
3. **Stream for UX**: Use streaming for better user experience
4. **Add Instructions**: Provide session instructions for consistent behavior
5. **Handle Errors**: Implement proper error handling for production apps
