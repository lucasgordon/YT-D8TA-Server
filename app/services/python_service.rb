require "open3"

class PythonService
  def self.execute_script(script_path, *args)
    # Using Open3 for better process control and output capture
    stdout, stderr, status = Open3.capture3("python3 #{script_path} #{args.join(' ')}")

    if status.success?
      stdout
    else
      Rails.logger.error("Python script error: #{stderr}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("Error executing Python script: #{e.message}")
    nil
  end
end
