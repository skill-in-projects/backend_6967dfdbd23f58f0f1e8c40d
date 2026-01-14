require 'sinatra'
require 'pg'
require 'json'
require 'logger'
require_relative 'Controllers/test_controller'

# Configure logging - Warning and Error only
LOG_LEVEL = ENV['LOG_LEVEL'] || 'WARN'
logger = Logger.new(STDOUT)
logger.level = Logger.const_get(LOG_LEVEL)
logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{severity}] #{datetime}: #{msg}\n"
end

# Use logger in Sinatra
set :logger, logger

# Port and bind settings - Puma config file (puma.rb) will override these
# But we set them here as fallback
set :port, (ENV['PORT'] || 8080).to_i
set :bind, '0.0.0.0'

# CORS headers
before do
    headers 'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers' => 'Content-Type'
end

options '*' do
    200
end

# Database connection
def get_db
    database_url = ENV['DATABASE_URL']
    raise 'DATABASE_URL environment variable not set' unless database_url
    
    PG.connect(database_url)
end

# Helper to parse JSON body
def parse_json_body
    request.body.rewind
    JSON.parse(request.body.read)
rescue JSON::ParserError
    {}
end

# Root endpoint
get '/' do
    content_type :json
    {
        message: 'Backend API is running',
        status: 'ok',
        swagger: '/swagger',
        api: '/api/test'
    }.to_json
end

# Health check
get '/health' do
    content_type :json
    {
        status: 'healthy',
        service: 'Backend API'
    }.to_json
end

# Swagger UI endpoint - serve interactive Swagger UI HTML page
get '/swagger' do
    content_type :html
    <<-HTML
<!DOCTYPE html>
<html>
<head>
    <title>Backend API - Swagger UI</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />
    <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin:0; background: #fafafa; }
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {
            const ui = SwaggerUIBundle({
                url: "/swagger.json",
                dom_id: "#swagger-ui",
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout"
            });
        };
    </script>
</body>
</html>
    HTML
end

# Swagger JSON endpoint - return OpenAPI spec as JSON
get '/swagger.json' do
    content_type :json
    {
        openapi: '3.0.0',
        info: {
            title: 'Backend API',
            version: '1.0.0',
            description: 'Ruby Backend API Documentation'
        },
        paths: {
            '/api/test' => {
                get: {
                    summary: 'Get all test projects',
                    responses: {
                        '200' => {
                            description: 'List of test projects',
                            content: {
                                'application/json' => {
                                    schema: {
                                        type: 'array',
                                        items: { '$ref' => '#/components/schemas/TestProjects' }
                                    }
                                }
                            }
                        }
                    }
                },
                post: {
                    summary: 'Create a new test project',
                    requestBody: {
                        required: true,
                        content: {
                            'application/json' => {
                                schema: { '$ref' => '#/components/schemas/TestProjectsInput' }
                            }
                        }
                    },
                    responses: {
                        '201' => {
                            description: 'Created test project',
                            content: {
                                'application/json' => {
                                    schema: { '$ref' => '#/components/schemas/TestProjects' }
                                }
                            }
                        }
                    }
                }
            },
            '/api/test/{id}' => {
                get: {
                    summary: 'Get test project by ID',
                    parameters: [
                        {
                            name: 'id',
                            'in' => 'path',
                            required: true,
                            schema: { type: 'integer' }
                        }
                    ],
                    responses: {
                        '200' => {
                            description: 'Test project found',
                            content: {
                                'application/json' => {
                                    schema: { '$ref' => '#/components/schemas/TestProjects' }
                                }
                            }
                        },
                        '404' => { description: 'Project not found' }
                    }
                },
                put: {
                    summary: 'Update test project',
                    parameters: [
                        {
                            name: 'id',
                            'in' => 'path',
                            required: true,
                            schema: { type: 'integer' }
                        }
                    ],
                    requestBody: {
                        required: true,
                        content: {
                            'application/json' => {
                                schema: { '$ref' => '#/components/schemas/TestProjectsInput' }
                            }
                        }
                    },
                    responses: {
                        '200' => { description: 'Updated test project' },
                        '404' => { description: 'Project not found' }
                    }
                },
                delete: {
                    summary: 'Delete test project',
                    parameters: [
                        {
                            name: 'id',
                            'in' => 'path',
                            required: true,
                            schema: { type: 'integer' }
                        }
                    ],
                    responses: {
                        '200' => { description: 'Deleted successfully' },
                        '404' => { description: 'Project not found' }
                    }
                }
            }
        },
        components: {
            schemas: {
                TestProjects: {
                    type: 'object',
                    properties: {
                        Id: { type: 'integer' },
                        Name: { type: 'string' }
                    }
                },
                TestProjectsInput: {
                    type: 'object',
                    required: ['Name'],
                    properties: {
                        Name: { type: 'string' }
                    }
                }
            }
        }
    }.to_json
end

# GET /api/test - Get all projects
get '/api/test' do
    content_type :json
    begin
        db = get_db
        controller = TestController.new(db)
        controller.get_all.to_json
    rescue => e
        status 500
        { error: e.message }.to_json
    ensure
        db&.close
    end
end

get '/api/test/' do
    content_type :json
    begin
        db = get_db
        controller = TestController.new(db)
        controller.get_all.to_json
    rescue => e
        status 500
        { error: e.message }.to_json
    ensure
        db&.close
    end
end

# GET /api/test/:id - Get project by ID
get '/api/test/:id' do
    content_type :json
    begin
        db = get_db
        controller = TestController.new(db)
        result = controller.get_by_id(params['id'].to_i)
        
        if result.nil?
            status 404
            { error: 'Project not found' }.to_json
        else
            result.to_json
        end
    rescue => e
        status 500
        { error: e.message }.to_json
    ensure
        db&.close
    end
end

# POST /api/test - Create project
post '/api/test' do
    content_type :json
    begin
        db = get_db
        controller = TestController.new(db)
        data = parse_json_body
        result = controller.create(data)
        status 201
        result.to_json
    rescue => e
        status 500
        { error: e.message }.to_json
    ensure
        db&.close
    end
end

post '/api/test/' do
    content_type :json
    begin
        db = get_db
        controller = TestController.new(db)
        data = parse_json_body
        result = controller.create(data)
        status 201
        result.to_json
    rescue => e
        status 500
        { error: e.message }.to_json
    ensure
        db&.close
    end
end

# PUT /api/test/:id - Update project
put '/api/test/:id' do
    content_type :json
    begin
        db = get_db
        controller = TestController.new(db)
        data = parse_json_body
        result = controller.update(params['id'].to_i, data)
        
        if result.nil?
            status 404
            { error: 'Project not found' }.to_json
        else
            result.to_json
        end
    rescue => e
        status 500
        { error: e.message }.to_json
    ensure
        db&.close
    end
end

# DELETE /api/test/:id - Delete project
delete '/api/test/:id' do
    content_type :json
    begin
        db = get_db
        controller = TestController.new(db)
        
        if controller.delete(params['id'].to_i)
            { message: 'Deleted successfully' }.to_json
        else
            status 404
            { error: 'Project not found' }.to_json
        end
    rescue => e
        status 500
        { error: e.message }.to_json
    ensure
        db&.close
    end
end
