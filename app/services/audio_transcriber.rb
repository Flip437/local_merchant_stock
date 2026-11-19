# Voice note → text (OpenAI Whisper by default).
class AudioTranscriber
  def initialize(client: OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY")),
                 model: ENV.fetch("OPENAI_TRANSCRIPTION_MODEL", "whisper-1"))
    @client = client
    @model = model
  end

  def call(io:, filename:, content_type:)
    file = OpenAI::FilePart.new(io, filename: filename, content_type: content_type)
    @client.audio.transcriptions.create(file: file, model: @model, language: "fr").text
  end
end
