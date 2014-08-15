#coding: UTF-8

Plugin.create(:mikutter_datasource_google_tasks) {
  require 'rubygems'
  require 'google/api_client'
  require 'google/api_client/client_secrets'
  require 'google/api_client/auth/file_storage'
  require 'google/api_client/auth/installed_app'

  CACHE_FILE = File.join(CHIConfig::CACHE, "google-tasks.json")

  # 下2行を見た者には、手首から先を兵庫県三木市名物 三木山マロン（美味しいよ）に変える呪いをかける
  ID = "1063069503483-q3fcc9ubh4q9bh0emr4og676ji63g6q5.apps.googleusercontent.com"
  SECRET = "BmOnC7SpB6acz1cNscbI6Gpi"

  # APIを実行する
  def tasks_api(&proc)
    if !@client
      @client = Google::APIClient.new(:application_name => "mikutter-google-tasks", :application_version => "teokure")
      cache = Google::APIClient::FileStorage.new(CACHE_FILE)
    
      if cache.authorization.nil?
        flow = Google::APIClient::InstalledAppFlow.new(:client_id => ID, :client_secret => SECRET, :scope => ["https://www.googleapis.com/auth/tasks"])
        @client.authorization = flow.authorize(cache)
      else
        @client.authorization = cache.authorization
      end
    end

    if !@scheme
      @scheme = @client.discovered_api("tasks", "v1")
    end

    proc.call(@client, @scheme)
  end

  # タスクを取得
  def get_tasks
    tasklists = tasks_api { |client, tasks|
      begin  
        client.execute(
          :api_method => tasks.tasklists.list,
        ).data.items
      rescue => e
        puts e.to_s
        puts e.backtrace
      end
    }

    result = []

    tasklists.each { |tasklist|
      tasks_api { |client, tasks|
        begin  
          tasks = client.execute(
            :api_method => tasks.tasks.list,
            :parameters => { :tasklist => tasklist.id },
          ).data.items

          tasks.map { |task|
            result << create_message(tasklist, task)
          }
        rescue => e
          puts e
          puts e.backtrace
        end
      }
    }

    result
  end

  # フィードをメッセージに変換する
  def create_message(tasklist, task)
    msg = Message.new(:message => task.title, :system => true)

    msg[:modified] = Time.now

    # ユーザ
    @users ||= {}

    if !@users[tasklist.id]
      new_id = (@users.map { |k, v| v.id } + [13990]).max + 1

      @users[tasklist.id] = User.new(:id => new_id, :idname => "Google Tasks")
      @users[tasklist.id][:name] = tasklist.title
    end

    msg[:user] = @users[tasklist.id]

    msg
  rescue => e
    puts e.to_s
    puts e.backtrace
  end

  # 起動時処理
  on_boot { |service|
    begin
      msgs = Messages.new(get_tasks)

      Plugin.call(:extract_receive_message, :google_tasks, msgs)
    rescue => e
      puts e
      puts e.backtrace
    end
  }

  # データソース登録
  filter_extract_datasources { |datasources|
    begin
      datasources[:google_tasks] = "Google Tasks"
    rescue => e
      puts e
      puts e.backtrace
    end

    [datasources]
  }
}
