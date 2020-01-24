require 'faraday'
require 'faraday_middleware'
require 'json'

module Teamwork

  VERSION = "1.0.7"

  class API

    def initialize(project_name: nil, api_key: nil)
      @project_name = project_name
      @api_key = api_key
      @api_conn = Faraday.new(url: "http://#{project_name}.teamworkpm.net/") do |c|
        c.request :multipart
        c.request :json
        c.request :url_encoded
        c.response :json, content_type: /\bjson$/
        c.adapter :net_http
      end

      @api_conn.headers[:cache_control] = 'no-cache'
      @api_conn.basic_auth(api_key, '')
      @api_conn = ResponseChecker.new @api_conn
    end

    def account(request_params)
      response = @api_conn.get "account.json", request_params
      response.body
    end

    # TODO new request
    def project_time_totals(id, request_params)
      response = @api_conn.get "projects/#{id}/time/total.json", request_params
      response.body
    end

    def people(request_params = nil)
      response = @api_conn.get "people.json", request_params
      response.body
    end

    def projects(request_params = nil)
      response = @api_conn.get "projects.json", request_params
      response.body
    end

    def project_people(id)
      response = @api_conn.get "projects/#{id}/people.json", nil
      response.body
    end

    def has_person_assigned_to_project(project_id, person_id)
      response = @api_conn.get "projects/#{project_id}/people/#{person_id}.json", nil
      response.body
    end

    def assign_people(id, params)
      @api_conn.put "/projects/#{id}/people.json", params
    end

    def create_person(params)
      @api_conn.post 'people.json', params
    end

    def get_person(person_id, params = nil)
      @api_conn.get "/people/#{person_id}.json", params
    end

    def latestActivity(maxItems: 60, onlyStarred: false)
      request_params = {
        maxItems: maxItems,
        onlyStarred: onlyStarred
      }
      response = @api_conn.get "latestActivity.json", request_params
      response.body
    end

    def get_comment(id)
      response = @api_conn.get "comments/#{id}.json"
      response.body["comment"]
    end

    def companies(params = nil)
      @api_conn.get 'companies.json', params
    end

    def get_people_within_company(company_id, params = nil)
      @api_conn.get "/companies/#{company_id}/people.json", params
    end

    def get_company_id(name)
      Hash[@api_conn.get('companies.json').body["companies"].map { |c| [c['name'], c['id']] }][name]
    end

    def create_company(name)
      @api_conn.post 'companies.json', { company: { name: name } }
    end

    def update_company(company_id, name)
      company = @api_conn.put("companies/#{company_id}.json", {
        "company" => {
          id: company_id,
          name: name
        }
      })
    end

    def get_or_create_company(name)
      create_company(name) if !get_company_id(name)
      get_company_id(name)
    end

    def create_project(name, client_name)
      result = {}
      company_id = get_or_create_company(client_name)
      project_id = @api_conn.post('projects.json', {
        project: {
          name: name,
          companyId: company_id,
          "category-id" => '0',
          includePeople: false
        }
      }).headers['id']
      result[:project_id] = project_id
      result[:company_id] = company_id
      result
    end

    def update_project(id, name, client_name, status)
      company_id = get_or_create_company(client_name)
      @api_conn.put("projects/#{id}.json", {
        project: {
          name: name,
          companyId: company_id,
          status: status
        }
      }).status
    end

    def mark_task_completed(project_id, task_id)
      @api_conn.put "tasks/#{task_id}/complete.json", nil
    end

    def retrieve_all_tasks(project_id)
      response = @api_conn.get "projects/#{project_id}/tasks.json", nil
      response.body
    end

    def delete_project(id)
      @api_conn.delete "projects/#{id}.json"
    end

    def delete_person(id)
      @api_conn.delete "/people/#{id}.json"
    end

    def get_project(id)
      @api_conn.get("projects/#{id}.json", {
        includePeople: true
      })
    end

    def get_task_lists(project_id)
      responses = @api_conn.get "/projects/#{project_id}/tasklists.json"

      responses.body
    end

    def get_tasks(project_id)
      @api_conn.get "/projects/#{project_id}/tasks.json"
    end

    def add_task_to_tasklist(task_list_id, task_data)
      response = @api_conn.post "/tasklists/#{task_list_id}/tasks.json", { 'todo-item' => task_data }

      response.body
    end

    def add_comment_to_task(task_id, comment_data)
      @api_conn.post "/tasks/#{task_id}/comments.json", { comment: comment_data }
    end

    def upload_file(file_path)
      payload = { :file => Faraday::UploadIO.new(file_path, 'image/jpeg') }
      @api_conn.post "/pendingfiles.json", payload
    end

    def add_file_to_task(task_id, attachment_ref)
      @api_conn.post "/tasks/#{task_id}/files.json", {
        "task" => {
          "pendingFileAttachments" => [attachment_ref],
          "updateFiles" => true,
          "removeOtherFiles" => false,
          "attachments" => "",
          "attachmentsCategoryIds" => "",
          "pendingFileAttachmentsCategoryIds" => "0"
        }
      }
    end

    def attach_post_to_project(title, body, project_id)
      @api_conn.post "projects/#{project_id}/posts.json", { post: { title: title, body: body } }
    end
  end
  class ResponseChecker
    attr_accessor :client

    def initialize(client)
      @client = client
    end

    def method_missing(sym, *args, &block)
      response = client.send sym, *args, &block
      unless response.success?
        raise Teamwork::Errors::Unreachable.new(response.status), "Can't reach teamwork (#{response.status}) - Make sure that token and site name are correct" if response.body.nil?
        raise Teamwork::Errors::BadRequest.new(response.status), "#{args.join ' '} \n\r #{response.body['MESSAGE'] || response.body['CONTENT']['MESSAGE']}"
      end

      response
    end
  end
  module Errors
    class Error < StandardError
      attr_accessor :code
    end
    class Unreachable < Error
      def initialize(code)
        @code = code
      end
    end

    class BadRequest < Error
      def initialize(code)
        @code = code
      end
    end
  end

end


