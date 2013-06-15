require 'zip/zip'
require 'fileutils'
require 'yaml'

class RappaError < Exception;
end

class Rappa

  SUPPORTED_SERVERS = %w(thin unicorn webrick)

  def initialize(config={})
    @config = config
    unless @config[:input_directory].nil?
      @config[:file_name] = (@config[:input_directory] == '.') ? 'default' : File.basename(@config[:input_directory])
    end
  end

  def package
    check_property(@config[:input_directory], :input_directory)
    check_property(@config[:output_directory], :output_directory)
    input_directory = append_trailing_slash(@config[:input_directory])
    raise RappaError, "input directory: #{input_directory} does not exist" unless File.exists?(input_directory)
    output_directory = @config[:output_directory]
    FileUtils.mkdir_p output_directory unless File.exists?(output_directory)
    name = "#{@config[:output_directory]}/#{@config[:file_name]}.rap"
    raise RappaError, "a rap archive already exists with the name: #{@config[:file_name]}.rap - please remove it and try again" if File.exists?(name)
    validate(input_directory)
    Zip::ZipFile.open(name, Zip::ZipFile::CREATE) do |zip_file|
      Dir[File.join(input_directory, '**', '**')].each do |file|
        zip_file.add(file.sub(input_directory, ''), file)
      end
    end
  end

  def expand
    check_property(@config[:input_archive], :input_archive)
    check_property(@config[:output_archive], :output_archive)
    raise RappaError, "input archive: #{@config[:input_archive]} does not exist" unless File.exists?(@config[:input_archive])
    validate_is_rap_archive
    output_directory = @config[:output_archive]
    FileUtils.mkdir_p output_directory unless File.exists?(output_directory)
    Zip::ZipFile.open(@config[:input_archive]) { |zip_file|
      zip_file.each { |f|
        f_path=File.join(calculate_destination, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        zip_file.extract(f, f_path) { true } unless File.exist?(f_path) # true will overwrite existing files.
      }
    }
  end

  def generate
    sample = {:server_type => 'thin', :start_script => './start.sh', :stop_script => './stop.sh'}
    File.open('sample.rap.yml', 'w') { |f| f.puts sample.to_yaml }
  end

  protected

  def install
    expand
    validate(calculate_destination)
  end

  private

  def check_property(property, property_type)
    raise RappaError, "property #{property_type} is mandatory but was not supplied" if property.nil? or property.empty?
  end

  def validate(directory)
    rap_file = directory + '/rap.yml'
    if File.exists?(rap_file)
      rap = YAML.load_file(rap_file)
      raise RappaError, "rap.yml :server_type is required and must be one of: #{SUPPORTED_SERVERS}" if rap[:server_type].nil? or rap[:server_type].empty?
      raise RappaError, "rap.yml :server_type supplied: #{rap[:server_type]} is not in the supported server list: #{SUPPORTED_SERVERS}" unless SUPPORTED_SERVERS.include?(rap[:server_type])
      raise RappaError, 'rap.yml :start_script is required' if rap[:start_script].nil? or rap[:start_script].empty?
      raise RappaError, 'rap.yml :stop_script is required' if rap[:stop_script].nil? or rap[:stop_script].empty?
    else
      raise RappaError, 'rap.yml file is required - please run rappa generate to create a sample rap.yml'
    end
  end

  def validate_is_rap_archive
    base_name = File.basename(@config[:input_archive])
    extension = File.extname(base_name)
    raise RappaError, "input archive: #{@config[:input_archive]} is not a valid .rap archive" unless extension == '.rap'
  end

  def calculate_destination
    base_name = File.basename(@config[:input_archive])
    name = base_name.chomp(File.extname(base_name))
    @config[:output_archive] + '/' + name
  end

  def append_trailing_slash(path)
    path = "#{path}/" if path[-1] != '/'
    path
  end

end