import psycopg2
import psycopg2.extras
from datetime import datetime
import logging
import re

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class PostgreSQLSelectIntoGenerator:
    def __init__(self, db_config):
        """
        Initialize with database configuration
        db_config: Dictionary with connection parameters
        """
        self.db_config = db_config
    
    def get_connection(self):
        """Get database connection"""
        return psycopg2.connect(**self.db_config)
    
    def analyze_query_structure(self, query):
        """Analyze the query to determine column types"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                # Execute query with LIMIT 0 to get column structure without data
                analyze_query = f"SELECT * FROM ({query}) AS subquery LIMIT 0"
                cur.execute(analyze_query)
                
                # Get column information
                columns = []
                for desc in cur.description:
                    col_name = desc.name
                    col_type = self.get_postgres_type(desc.type_code)
                    columns.append({
                        'name': col_name,
                        'type': col_type,
                        'type_code': desc.type_code
                    })
                
                return columns
        finally:
            conn.close()
    
    def get_postgres_type(self, type_code):
        """Map PostgreSQL type codes to type names"""
        type_mapping = {
            23: 'INTEGER',          # int4
            20: 'BIGINT',           # int8
            21: 'SMALLINT',         # int2
            700: 'REAL',            # float4
            701: 'DOUBLE PRECISION', # float8
            1700: 'NUMERIC',        # numeric
            25: 'TEXT',             # text
            1043: 'VARCHAR',        # varchar
            1042: 'CHAR',           # char
            16: 'BOOLEAN',          # bool
            1082: 'DATE',           # date
            1083: 'TIME',           # time
            1114: 'TIMESTAMP',      # timestamp
            1184: 'TIMESTAMPTZ',    # timestamptz
            114: 'JSON',            # json
            3802: 'JSONB',          # jsonb
            2950: 'UUID',           # uuid
        }
        return type_mapping.get(type_code, 'TEXT')
    
    def generate_select_into_query(self, source_query, target_table, schema='public', add_metadata=True):
        """
        Generate SELECT INTO query
        source_query: The source SELECT query
        target_table: Name of the target table
        schema: Target schema (default: public)
        add_metadata: Whether to add metadata columns
        """
        # Clean the source query
        source_query = source_query.strip()
        if source_query.endswith(';'):
            source_query = source_query[:-1]
        
        # Build the SELECT INTO query
        if add_metadata:
            select_into_query = f"""
            SELECT 
                *,
                '{target_table}' AS source_table,
                CURRENT_TIMESTAMP AS created_at
            INTO {schema}.{target_table}
            FROM ({source_query}) AS source_data;
            """
        else:
            select_into_query = f"""
            SELECT *
            INTO {schema}.{target_table}
            FROM ({source_query}) AS source_data;
            """
        
        return select_into_query.strip()
    
    def generate_create_table_as_query(self, source_query, target_table, schema='public', add_metadata=True):
        """
        Generate CREATE TABLE AS query (alternative to SELECT INTO)
        """
        # Clean the source query
        source_query = source_query.strip()
        if source_query.endswith(';'):
            source_query = source_query[:-1]
        
        if add_metadata:
            create_table_query = f"""
            CREATE TABLE {schema}.{target_table} AS
            SELECT 
                *,
                '{target_table}' AS source_table,
                CURRENT_TIMESTAMP AS created_at
            FROM ({source_query}) AS source_data;
            """
        else:
            create_table_query = f"""
            CREATE TABLE {schema}.{target_table} AS
            SELECT *
            FROM ({source_query}) AS source_data;
            """
        
        return create_table_query.strip()
    
    def execute_select_into(self, source_query, target_table, schema='public', 
                           method='select_into', drop_if_exists=True, add_metadata=True):
        """
        Execute SELECT INTO or CREATE TABLE AS
        method: 'select_into' or 'create_table_as'
        """
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                full_table_name = f"{schema}.{target_table}"
                
                # Drop table if exists
                if drop_if_exists:
                    cur.execute(f"DROP TABLE IF EXISTS {full_table_name};")
                    logger.info(f"Dropped table {full_table_name} if it existed")
                
                # Generate and execute the appropriate query
                if method == 'select_into':
                    query = self.generate_select_into_query(source_query, target_table, schema, add_metadata)
                else:
                    query = self.generate_create_table_as_query(source_query, target_table, schema, add_metadata)
                
                logger.info(f"Executing query:\n{query}")
                cur.execute(query)
                
                # Get row count
                cur.execute(f"SELECT COUNT(*) FROM {full_table_name};")
                row_count = cur.fetchone()[0]
                
                conn.commit()
                logger.info(f"✅ Successfully created table {full_table_name} with {row_count} rows")
                
                return {
                    'table_name': full_table_name,
                    'row_count': row_count,
                    'query_executed': query
                }
                
        except Exception as e:
            conn.rollback()
            logger.error(f"❌ Failed to create table {schema}.{target_table}: {str(e)}")
            raise
        finally:
            conn.close()
    
    def create_table_from_query_with_structure(self, source_query, target_table, schema='public'):
        """
        Create table with explicit column definitions (more control)
        """
        conn = self.get_connection()
        try:
            # First analyze the query structure
            columns = self.analyze_query_structure(source_query)
            
            with conn.cursor() as cur:
                full_table_name = f"{schema}.{target_table}"
                
                # Drop table if exists
                cur.execute(f"DROP TABLE IF EXISTS {full_table_name};")
                
                # Build CREATE TABLE statement
                column_definitions = []
                for col in columns:
                    column_definitions.append(f'"{col["name"]}" {col["type"]}')
                
                # Add metadata columns
                column_definitions.extend([
                    '"source_table" TEXT',
                    '"created_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP'
                ])
                
                create_sql = f"""
                CREATE TABLE {full_table_name} (
                    {', '.join(column_definitions)}
                );
                """
                
                cur.execute(create_sql)
                logger.info(f"Created table structure for {full_table_name}")
                
                # Insert data
                insert_sql = f"""
                INSERT INTO {full_table_name} 
                SELECT 
                    *,
                    '{target_table}' AS source_table,
                    CURRENT_TIMESTAMP AS created_at
                FROM ({source_query}) AS source_data;
                """
                
                cur.execute(insert_sql)
                
                # Get row count
                cur.execute(f"SELECT COUNT(*) FROM {full_table_name};")
                row_count = cur.fetchone()[0]
                
                conn.commit()
                logger.info(f"✅ Successfully created and populated table {full_table_name} with {row_count} rows")
                
                return {
                    'table_name': full_table_name,
                    'row_count': row_count,
                    'columns': columns,
                    'create_sql': create_sql,
                    'insert_sql': insert_sql
                }
                
        except Exception as e:
            conn.rollback()
            logger.error(f"❌ Failed to create structured table {schema}.{target_table}: {str(e)}")
            raise
        finally:
            conn.close()
    
    def batch_create_tables(self, queries_config):
        """
        Create multiple tables from a list of query configurations
        queries_config: List of dicts with 'query', 'table_name', 'schema' keys
        """
        results = []
        
        for config in queries_config:
            try:
                result = self.execute_select_into(
                    source_query=config['query'],
                    target_table=config['table_name'],
                    schema=config.get('schema', 'public'),
                    method=config.get('method', 'select_into'),
                    drop_if_exists=config.get('drop_if_exists', True),
                    add_metadata=config.get('add_metadata', True)
                )
                results.append(result)
                
            except Exception as e:
                logger.error(f"❌ Failed to process {config['table_name']}: {str(e)}")
                results.append({
                    'table_name': config['table_name'],
                    'error': str(e)
                })
                continue
        
        return results

# Example usage
if __name__ == "__main__":
    # Database configuration
    db_config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'your_database',
        'user': 'your_user',
        'password': 'your_password'
    }
    
    # Initialize generator
    generator = PostgreSQLSelectIntoGenerator(db_config)
    
    # Example 1: Simple SELECT INTO
    source_query = "SELECT * FROM users WHERE created_at > '2024-01-01'"
    result = generator.execute_select_into(
        source_query=source_query,
        target_table="recent_users",
        schema="analytics"
    )
    print(f"Created table: {result['table_name']} with {result['row_count']} rows")
    
    # Example 2: Generate query without executing
    select_into_sql = generator.generate_select_into_query(
        source_query="SELECT name, email FROM users",
        target_table="user_contacts",
        schema="reports"
    )
    print(f"Generated SQL:\n{select_into_sql}")
    
    # Example 3: Batch create tables
    batch_config = [
        {
            'query': "SELECT * FROM orders WHERE status = 'completed'",
            'table_name': 'completed_orders',
            'schema': 'analytics'
        },
        {
            'query': "SELECT customer_id, COUNT(*) as order_count FROM orders GROUP BY customer_id",
            'table_name': 'customer_order_counts',
            'schema': 'analytics'
        }
    ]
    
    batch_results = generator.batch_create_tables(batch_config)
    for result in batch_results:
        if 'error' in result:
            print(f"❌ {result['table_name']}: {result['error']}")
        else:
            print(f"✅ {result['table_name']}: {result['row_count']} rows")
    
    # Example 4: Create table with explicit structure
    structured_result = generator.create_table_from_query_with_structure(
        source_query="SELECT id, name, email, created_at FROM users",
        target_table="user_snapshot",
        schema="snapshots"
    )
    print(f"Created structured table with columns: {[col['name'] for col in structured_result['columns']]}")