class Repo < ActiveRecord::Base
  attr_accessible :owner, :name
  validates_presence_of :name, :owner
  has_many :todo_files, dependent: :destroy
  has_many :todo_lines, through: :todo_files

  def real?
    begin
      http_get("repos/#{owner}/#{name}")
    rescue RestClient::ResourceNotFound
      false
    end
  end

  def updated?
    begin
      http_get("repos/#{owner}/#{name}", "If-Modified-Since" => "#{updated_at.httpdate}")
    rescue RestClient::NotModified
      false
    end
  end

  def updatable?
    tree.length + 100 < rate_remaining # '+100' is to be safe
  end

  def update!
    TodoFile.destroy_all(repo_id: id)
    todos.each_value do |todo|
      t = todo_files.create(todo.reject { |k, v| k == :lines })
      todo[:lines].each do |line|
        t.todo_lines.create( line_num: line )
      end
    end
    update_info!
  end

  private

  def rate_remaining
    response = json_get("rate_limit")
    response[:rate][:remaining]
  end

  def update_info!
    self.github_created_at = info[:created_at]
    self.github_updated_at = info[:updated_at]
    self.homepage = info[:homepage]
    self.description = info[:description]
    self.language = info[:language]
    self.forks = info[:forks]
    self.stars = info[:watchers]
    self.issues = info[:open_issues]
    self.save
  end

  def info
    return @info if @info
    @info = json_get("repos/#{owner}/#{name}")
  end

  def tree
    return @tree if @tree
    path = "repos/#{owner}/#{name}/git/trees/master"
    response = json_get(path, :params => {:recursive => true} )
    @tree = response[:tree]
  end


  # Currently running into problems when analyzing files with no filetype extensions.
  def todos # Formerly 'files'
    return @todos if @todos
    @todos = {}
    tree.find_all { |f| f[:type] == "blob" }.each do |file|
      if extension?(file[:path]) # Makes sure that there is a file extension
        filetype = parse_file_ext(file[:path])
        if content(file[:sha]) =~ /todo|to do|bugbug|bug/i
          @todos[file[:sha]] = { path: file[:path], sha: file[:sha], lines: lines(filetype), content: @content }
        end
      end
    end
    @todos
  end

  def content(sha)
    @content = http_get("repos/#{owner}/#{name}/git/blobs/#{sha}", :accept => "application/vnd.github-blob.raw")
  end

  def lines(filetype)
=begin
  1. Figure out the language based on the file path
  2. Figure out the commenting syntax for that language
    a. single line
    b. multi line
  3. Parse through the content to look for comments, depending on the language
    a. if single line
      -search for TODOS and BUGBUGs until the end of the line
    b. if multiline
      -search for todos and bubugs until ending comment syntax (eg- for ruby, its '=end')
=end
    line_arr = []
    @content.split(%r{\n}).each_with_index do |line, index|
      case filetype
      when "rb"
        if any_todos?(line, "#")
          line_arr << index + 1
        end
      when "py"
        line_arr << index + 1 unless line.any_todos?("//").empty?
      else
        []
      end
    end
    line_arr
  end

  def any_todos?(text, comment) # This will only work for // and # style comments.
    regex = /^[\t ]*[^\s#{comment}][^#{comment}\n\r]*#{comment}([^#{comment}\n\r]*[todo|to do|bugbug|bug]*.*)/i
    !text.scan(regex).flatten.empty?
  end

  def parse_file_ext(value)
    value.match(/\.\w+/i)[0][1..-1]  # Returns first instance of everything after the first dot
  end

  def extension?(value)
    !value.match(/\.\w+/i).nil?
  end

  def json(string)
    JSON.parse(string, :symbolize_names => true)
  end

  def http_get(path, opts = {})
    url = "https://api.github.com/" + path
    RestClient.get(url, opts)
  end

  def json_get(path, opts = {})
    response = http_get(path, opts)
    json(response)
  end
end
