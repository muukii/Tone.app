import SwiftUI

struct VocabularyCardView: View {
  let input: String
  let meaning: String
  let ipa: String
  let partsOfSpeech: String
  let synonyms: [String]
  let sentences: [String]
  
  let speechClient: SpeechClient
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading) {
            Text(input)
              .font(.largeTitle.bold())
            
            if !ipa.isEmpty {
              Text(ipa)
                .font(.title3.monospaced())
                .foregroundStyle(.secondary)
            }
          }
          
          Spacer()
          
          Button(action: {            
            speechClient.speak(text: input)
          }) {
            Image(systemName: "speaker.wave.2")
              .font(.title)
          }
          .buttonStyle(.bordered)
        }
        
        Divider()
        
        Text(meaning)
          .font(.title2)
        
        if !partsOfSpeech.isEmpty {
          Text(partsOfSpeech)
            .font(.subheadline)
            .padding(.top, 4)
        }
        
        if !synonyms.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Synonyms:")
              .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
              HStack {
                ForEach(synonyms, id: \.self) { synonym in
                  Text(synonym)
                    .padding(8)
                    .background(
                      RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
              }
            }
          }
          .padding(.top, 8)
        }
        
        if !sentences.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Example Sentences:")
              .font(.headline)
            
            ForEach(sentences, id: \.self) { sentence in
              Text(sentence)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                )
            }
          }
          .padding(.top, 8)
        }
      }
      .padding()
    }
  }
}


#Preview("Vocabulary Card") {
  NavigationStack {
    VocabularyCardView(
      input: "water",
      meaning: "りんご（果物の一種）",
      ipa: "/ˈæpəl/",
      partsOfSpeech: "noun",
      synonyms: ["fruit", "pome", "orchard fruit"],
      sentences: [
        "I ate a juicy apple for breakfast.",
        "She picked an apple from the tree in the backyard.",
      ],
      speechClient: .init()
    )
  }
}

