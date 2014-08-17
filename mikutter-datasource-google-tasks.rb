#coding: UTF-8

Plugin.create(:mikutter_datasource_google_tasks) {
  require File.join(File.dirname(__FILE__), "google_tasks.rb")
  require File.join(File.dirname(__FILE__), "looper.rb")

  # リロード用ループ
  class ReloadLooper < Looper
    # タイマー設定
    def timer_set
      UserConfig[:google_tasks_period] * 60
    end

    # 処理
    def proc
      Delayer.new {
        @plugin.reload
      }
    end

    def initialize(plugin)
      super()
      @plugin = plugin
    end
  end

  # フィードをメッセージに変換する
  def create_message(tasklist, task)
    msg = Message.new(:message => task.title, :system => true)

    msg[:created] = task.updated
    msg[:modified] = Time.now

    # ユーザ
    @users ||= {}

    if !@users[tasklist.id]
      new_id = (@users.map { |k, v| v.id } + [13990]).max + 1

      @users[tasklist.id] = User.new(:id => new_id, :idname => "Google Tasks")
      @users[tasklist.id][:name] = tasklist.title
      @users[tasklist.id][:profile_image_url] = File.join(File.dirname(__FILE__), "MetroUI-Google-Task-icon.png")
    end

    msg[:user] = @users[tasklist.id]

    msg
  rescue => e
    puts e.to_s
    puts e.backtrace
  end

  # メッセージを更新する
  def reload
    @saved_msgs ||= []

    Plugin.call(:destroyed, @saved_msgs)

    task_infos = GoogleTasks.get_tasks

    if task_infos
      @saved_msgs = task_infos.map { |task_info|
        task_info[:tasks].select { |_| _.status != "completed" }
        .sort { |a, b| a.updated <=> b.updated }.map { |task|
          create_message(task_info[:tasklist], task)
        }
      }.flatten

      msgs = Messages.new(@saved_msgs)

      Plugin.call(:extract_receive_message, :google_tasks, msgs)
    end
  end

  # 起動時処理
  on_boot { |service|
    begin
      ReloadLooper.new(self).start
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

  # 抽出タブ設定変更
  on_extract_tab_update { |record|
    # データソースに自分が指定された
    if record[:sources].include?(:google_tasks)
      reload
    end
  }

  # 設定
  UserConfig[:google_tasks_period] ||= 10

  settings("Google Tasks") {
    adjustment("更新間隔（分）", :google_tasks_period, 1, 60)
  }

}
