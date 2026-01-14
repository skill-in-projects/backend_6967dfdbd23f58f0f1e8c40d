require_relative '../Models/test_projects'

class TestController
    def initialize(db)
        @db = db
    end

    def set_search_path
        # Set search_path to public schema (required because isolated role has restricted search_path)
        # Using string concatenation to avoid C# string interpolation issues
        @db.exec('SET search_path = public, "' + '$' + 'user"')
    end

    def get_all
        begin
            set_search_path
            result = @db.exec('SELECT "Id", "Name" FROM "TestProjects" ORDER BY "Id"')
            result.map do |row|
                {
                    'Id' => row['Id'].to_i,
                    'Name' => row['Name']
                }
            end
        rescue PG::Error => e
            raise "Database error: #{e.message}"
        end
    end

    def get_by_id(id)
        begin
            set_search_path
            result = @db.exec_params('SELECT "Id", "Name" FROM "TestProjects" WHERE "Id" = $1', [id])
            return nil if result.ntuples == 0
            
            row = result[0]
            {
                'Id' => row['Id'].to_i,
                'Name' => row['Name']
            }
        rescue PG::Error => e
            raise "Database error: #{e.message}"
        end
    end

    def create(data)
        begin
            set_search_path
            result = @db.exec_params('INSERT INTO "TestProjects" ("Name") VALUES ($1) RETURNING "Id", "Name"', [data['name']])
            row = result[0]
            {
                'Id' => row['Id'].to_i,
                'Name' => row['Name']
            }
        rescue PG::Error => e
            raise "Database error: #{e.message}"
        end
    end

    def update(id, data)
        begin
            set_search_path
            result = @db.exec_params('UPDATE "TestProjects" SET "Name" = $1 WHERE "Id" = $2 RETURNING "Id", "Name"', [data['name'], id])
            return nil if result.ntuples == 0
            
            row = result[0]
            {
                'Id' => row['Id'].to_i,
                'Name' => row['Name']
            }
        rescue PG::Error => e
            raise "Database error: #{e.message}"
        end
    end

    def delete(id)
        begin
            set_search_path
            result = @db.exec_params('DELETE FROM "TestProjects" WHERE "Id" = $1', [id])
            result.cmd_tuples > 0
        rescue PG::Error => e
            raise "Database error: #{e.message}"
        end
    end
end
