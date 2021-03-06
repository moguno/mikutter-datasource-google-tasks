#coding: UTF-8

class GoogleTasks
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
  def self.tasks_api(&proc)
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
  def self.get_tasks
    tasklists = tasks_api { |client, tasks|
      begin  
        client.execute(
          :api_method => tasks.tasklists.list
        ).data.items
      rescue => e
        puts e.to_s
        puts e.backtrace
      end
    }

    task_infos = tasklists.map { |tasklist|
      info = { :tasklist => tasklist, :tasks => [] }

      tasks_api { |client, tasks|
        result = client.execute(
          :api_method => tasks.tasks.list,
          :parameters => { :tasklist => tasklist.id },
        )

        if result.error?
          raise result.error_message
        end

        info[:tasks] = result.data.items
      }

      info
    }

    task_infos
  end

  # タスクを完了させる
  def self.complete_task(tasklist, task)
    tasks_api { |client, tasks|
      task2 = task.dup
      task2.status = "completed"

      result = client.execute(
        :api_method => tasks.tasks.update,
        :parameters => {
          :tasklist => tasklist.id,
          :task => task.id,
        },
        :body_object => task2)

      if result.error?
        raise result.error_message
      end
    }
  end
end
