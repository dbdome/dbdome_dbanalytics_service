import certifi
import ssl
from sentence_transformers import SentenceTransformer
import pandas as pd
import psycopg2
from utils.config_dotenv import get_connection_string  , get_llm
from sqlalchemy import create_engine, func , text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy import MetaData, Table
from sqlalchemy.dialects.postgresql import insert
from utils.log4dbexpert import db_write_log
from datetime import datetime, timezone
import pyodbc
import sqlparse
import sqlglot
import json
from fastai.tabular.all import *
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sqlparse.sql import IdentifierList, Identifier, Where, Comparison, Function
from sqlparse.tokens import Keyword, DML, Punctuation
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
import json
import re
import random


pyodbc.paramstyle = 'qmark'  # pyodbc uses '?' placeholders

sqli_patterns = {
    "union_select": re.compile(r"(?i)\bunion(\s+all)?\s+select\b"),
    "boolean_sqli": re.compile(r"(?i)\b(or)\b\s+1\s*=\s*1\b"),
    "stacked_query": re.compile(r";\s*(drop|truncate|alter|create|exec)\b", re.I),
    "commented_payload": re.compile(r"(--|#|/\*)"),
    "schema_access": re.compile(r"(?i)\b(information_schema|pg_catalog|sys\.tables|sys\.objects)\b"),
    "sleep_time": re.compile(r"(?i)\b(sleep|pg_sleep|waitfor\s+delay)\b"),
    "outfile_copy": re.compile(r"(?i)\binto\s+outfile\b|\bcopy\b.*to\s+(file|program)\b"),
    "dangerous_function": re.compile(r"(?i)\bxp_cmdshell|sp_executesql|pg_read_file|load_file\b"),
    "sensitive_columns": re.compile(r"(?i)\b(ssn|credit_card|card_number|cvv|password|api[_-]?key|token)\b"),
  "sensitive_columns": re.compile(r"(?i)\b(ssn|credit_card|card_number|cvv|password|api[_-]?key|token)\b"),
  "long_literal": re.compile(r"['\"][A-Za-z0-9=_\-+/]{30,}['\"]")
}


def detect_sql_threats(sql: str):
    """Return dict of rule matches and matched substrings."""
    hits = {}
    for name, pattern in sqli_patterns.items():
        match = pattern.findall(sql)
        hits[name] = len(match) > 0
    return hits

def extract_sql_features(sql: str):
    """Return feature dict for a single SQL query."""
    rules = detect_sql_threats(sql)
    
    # simple numeric stats
    length = len(sql)
    num_literals = len(re.findall(r"'[^']*'", sql))
    num_keywords = len(re.findall(r"\b(select|update|delete|insert|drop|union|where|and|or)\b", sql, re.I))
    num_comments = len(re.findall(r"(--|#|/\*)", sql))
    upper_ratio = sum(c.isupper() for c in sql) / max(1, len(sql))
    
    # merge with rule-based
    features = {**rules}
    features.update({
        "length": length,
        "num_literals": num_literals,
        "num_keywords": num_keywords,
        "num_comments": num_comments,
        "upper_ratio": upper_ratio
    })
    return features


    



def metrics_analyse_threats():
    result = 1
    try:
        #query_Analysis_nlp();
        metrics_analyse_identify_suspicous_queries();
    except Exception as e:
        result = 0
        db_write_log(f"metrics_analyse_threats failed with error:{e}"   , result ,"metrics_custom_metrics_analysis" ,"")
    finally:
        db_write_log(f"metrics_analyse_threats succeeded", result ,"metrics_sql_unification" ,"")
    return 1

def metrics_analyse_identify_suspicous_queries():    
    i =0;
    # PostgreSQL connection
    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string)
    metadata = MetaData(schema="monitoring")
    raw_conn = postgres_engine.raw_connection()
    p_sql_cmd = """
         SELECT 
            cq.row_id AS query_id,
            c.area_id || c.domain_id || c.id AS category,
            c.icon,
            c.description,
            c.name,
            cq.query
        FROM widget.categories c
        JOIN widget.categories_queries cq ON cq.category_id = c.row_id
		where c.domain_id  like 'd002'
    """
    try:
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)
        if df.empty:
            print("⚠️ No category queries found.")
            return
       
        for _, row in df.iterrows():
            i += 1;
            query_id    = row["query_id"]
            category    = row["category"]
            query       = row["query"]
            if isinstance(query, tuple):
                query = query[0]
            # Validate it's a string
            if not isinstance(query, str):
                raise TypeError(f"Expected query to be str, got {type(query)}")            
            icon        = row["icon"]
            description = row["description"]
            name        = row["name"]
            # Execute main query
            df_query = pd.read_sql_query(text(query), con=postgres_engine)
    
            if df_query.empty:
                print(f"⚠️ No data returned for query_id={query_id}")
                continue            
            for index, row in df_query.iterrows():                 
                try:
                    server     = row['server']  
                    query_text    = row['query']  
                    query_id    = row['query_id'] 
                    try:
                        parsed = sqlglot.parse_one(query_text)
                    except Exception as e:
                        db_write_log(f"metrics_analyse_threats failed with error: {e}", 0, "metrics_analyse_threats", "")
                    tables = [t.name for t in parsed.find_all(sqlglot.exp.Table)]
                    tables_j = json.dumps(tables)
                    columns = [c.name for c in parsed.find_all(sqlglot.exp.Column)]
                    columns_j = json.dumps(columns)
                    literals = [str(l) for l in parsed.find_all(sqlglot.exp.Literal)]
                    literals_j = json.dumps(literals);
                    has_union = "UNION" in query_text.upper()
                    has_comment = "--" in query_text or "/*" in query
                    suspicious_or = " OR " in query_text.upper() and "=" in query.upper()

                    with postgres_engine.begin() as conn:
                            conn.execute(
                                text("""
                                    delete from monitoring.sql_suspicious where query_id = :query_id
                                """),
                                {
                                    "query_id": int(query_id)
                                }
                            )
                            conn.commit();
                    with postgres_engine.begin() as conn:
                            conn.execute(
                                text("""
                                    INSERT INTO monitoring.sql_suspicious
                                        (query_id, query, tables ,columns ,literals ,  has_union ,  has_comment , suspicious_or , server)
                                    VALUES
                                        (:query_id, :query, :tables ,:columns ,:literals ,  :has_union ,  :has_comment , :suspicious_or , :server)
                                """),
                                {
                                    "query_id": int(query_id),
                                    "query": query_text,
                                    "tables": tables_j , 
                                    "columns":columns_j  , 
                                    "literals":literals_j ,
                                    "has_union":has_union,
                                    "has_comment":has_comment,
                                    "suspicious_or":suspicious_or , 
                                    "server":server
                                }
                            )
                            conn.commit();
                except Exception as e:
                    db_write_log(f"metrics_analyse_identify_suspicous_queries failed with error: {e}", 0, "metrics_analyse_identify_suspicous_queries", "")
    except Exception as e:
        db_write_log(f"metrics_analyse_identify_suspicous_queries failed with error: {e}", 0, "metrics_analyse_identify_suspicous_queries", "")
    finally:
        raw_conn.close()
        db_write_log("metrics_analyse_identify_suspicous_queries finished successfully", 0, "metrics_analyse_identify_suspicous_queries", "")

            

def query_Analysis_nlp():
    i =0;
    df_query = None
    # PostgreSQL connection
    pg_connection_string = get_connection_string()
    postgres_engine = create_engine(pg_connection_string)
    metadata = MetaData(schema="monitoring")
    raw_conn = postgres_engine.raw_connection()
    model = SentenceTransformer('all-MiniLM-L6-v2')
    try:     

        # Known threats from your list
        known_threats = [
                            "UNION SELECT password FROM users",
                            "DROP TABLE users",
                            "SELECT credit_card_number FROM payments",
                            "SELECT ssn, dob FROM users",
                            "INSERT INTO users (username, password)",
                            "DELETE FROM transactions WHERE 1=1"
                        ]

                        # Synthetic safe queries
        safe_queries = [
                            "SELECT * FROM products WHERE price < 100",
                            "INSERT INTO orders (user_id, amount) VALUES (1, 50)",
                            "UPDATE customers SET city='New York' WHERE id=5",
                            "SELECT COUNT(*) FROM visits WHERE date > now() - interval '7 days'",
                            "DELETE FROM logs WHERE created_at < now() - interval '30 days'"
                        ]

                        # Build dataset
        data = []
        for q in known_threats:
                            f = extract_sql_features(q)
                            f["query"] = q
                            f["label"] = 1
                            data.append(f)
        df_known_threats = get_known_threats();
        for index, row in df_known_threats.iterrows(): 
          f["query"] = row["query"]
          f["label"] = 1
          data.append(f)
        for q in safe_queries:
                            f = extract_sql_features(q)
                            f["query"] = q
                            f["label"] = 0
                            data.append(f)
        df_safe_queries = get_safe_queries();
        for index, row in df_known_threats.iterrows(): 
          f["query"] = row["query"]
          f["label"] = 0
          # define continuous/categorical
          data.append(f)
        df = pd.DataFrame(data)
        cont_names = [c for c in df.columns if c not in ["label", "query"]]    
        cat_names = []
        procs = [Normalize]    
    # train small neural net    
  
        model_path = get_llm()
        model = SentenceTransformer(model_path)         
        dls = TabularDataLoaders.from_df(df, y_names="label", cont_names=cont_names, cat_names=cat_names, procs=procs, bs=8)
        learn = tabular_learner(dls, metrics=accuracy)
        learn.fit_one_cycle(15, 1e-3)        
    except Exception as e:
        db_write_log(f"metrics_analyse_identify_suspicous_queries failed with error: {e}", 0, "metrics_analyse_identify_suspicous_queries", "")  
    p_sql_cmd = """
         SELECT 
            cq.row_id AS query_id,
            c.area_id || c.domain_id || c.id AS category,
            c.icon,
            c.description,
            c.name,
            cq.query
        FROM widget.categories c
        JOIN widget.categories_queries cq ON cq.category_id = c.row_id
		where c.domain_id  like 'd002'
    """
    try:
        df = pd.read_sql_query(p_sql_cmd, con=raw_conn)
        if df.empty:
            print("⚠️ No category queries found.")
            return
       
        for _, row in df.iterrows():

            i += 1;
            
            query_id    = row["query_id"]
            category    = row["category"]
            query       = row["query"]
            if isinstance(query, tuple):
                query = query[0]
            # Validate it's a string
            if not isinstance(query, str):
                raise TypeError(f"Expected query to be str, got {type(query)}")            
            icon        = row["icon"]
            description = row["description"]
            name        = row["name"]
            # Execute main query
            df_query = pd.read_sql_query(text(query), con=postgres_engine)    
            if df_query.empty:
                print(f"⚠️ No data returned for query_id={query_id}")
                continue
            with postgres_engine.begin() as conn:
                            conn.execute(
                                text("""
                                    update monitoring.sql_feature_predictions set update_status = 2 where update_status = 1;
                                    update monitoring.sql_predictions set update_status = 2 where update_status = 1; 
                                    delete from monitoring.sql_feature_predictions
                                        where query_id = :query_id
                                """),
                                {
                                    "query_id": int(query_id)
                                }
                            )
                            conn.commit();
            for index, row in df_query.iterrows():
                        server     = row['server']  
                        query_text    = row['query']  
                        query_id    = row['query_id']  
                        # Convert DataFrame rows to text
                        #texts = query_text.astype(str).agg(' '.join, axis=1).tolist()
                        # Create embeddings
                        embeddings = model.encode(query_text)
                        # Optional: store as a DataFrame
                        df_embeddings = pd.DataFrame(embeddings)
                        hits = detect_sql_threats(query_text);
                        features = extract_sql_features(query_text);                                                                                               
                        features["query"] = query_text
                        with postgres_engine.begin() as conn:
                            conn.execute(
                                text("""
                                    delete from monitoring.sql_feature_predictions
                                        where query_id = :query_id
                                """),
                                {
                                    "query_id": int(query_id)
                                }
                            )
                            conn.commit();
                        with postgres_engine.begin() as conn:
                            conn.execute(
                                text("""
                                    INSERT INTO monitoring.sql_feature_predictions
                                        (query_id, sql_text, features , server)
                                    VALUES
                                        (:qid, :sql_text, :features , :server )
                                    """),
                                    {   
                                    "qid": int(query_id),
                                    "sql_text": query_text,                                    
                                    "features": json.dumps(features)   ,  
                                    "server": server                                    
                                    }
                                        )
                            conn.commit();
                        df_new = pd.DataFrame([features])                        
                        label, idx, scores_tensor = learn.predict(df_new.iloc[0])
                        scores = json.dumps(scores_tensor.tolist())
                        predicted_index = int(idx)
                        predicted_label = str(label)  
                        try:
                            with postgres_engine.begin() as conn:
                                conn.execute(
                                text("""
                                    delete from  monitoring.sql_predictions 
                                    where query_id = :query_id
                                """),                                
                                {"query_id": int(query_id)}
                                )
                                with postgres_engine.begin() as conn:
                                    conn.execute(
                                        text("""
                                            INSERT INTO monitoring.sql_predictions
                                            (query_id,predicted_label,predicted_index,predicted_scores , server)
                                            VALUES (:qid,:predicted_label,:predicted_index,:predicted_scores , :server)
                                        """),
                                        {
                                            "qid": int(query_id),
                                            "predicted_label":predicted_label,
                                            "predicted_index": predicted_index,
                                            "predicted_scores":scores , 
                                            "server":server
                                            
                                        }
                                    )
                        except Exception as e:
                            db_write_log(f"query_Analysis_nlp failed with error: {e}", 0, "query_Analysis_nlp", "")
                        finally:
                           conn.commit();                                                   
                        
    except Exception as e:
        db_write_log(f"metrics_advisories failed with error: {e}", 0, "metrics_advisories", "")
    finally:
        raw_conn.close()
        db_write_log("metrics_advisories finished successfully", 0, "metrics_advisories", "")
        with postgres_engine.begin() as conn:
            conn.execute(
                                    text("""
                                        delete from monitoring.sql_feature_predictions  where update_status = 2;
                                        delete from monitoring.sql_predictions  where update_status = 2;
                                    """),
                                    {
                                        "query_id": int(query_id)
                                    }
                                )
            conn.commit();
    return df_query
def get_known_threats ():
        pg_connection_string = get_connection_string()
        postgres_engine = create_engine(pg_connection_string)
        metadata = MetaData(schema="monitoring")
        raw_conn = postgres_engine.raw_connection()
        p_sql_cmd = """
            select query from monitoring.v_suspiscous
    """
        df_known_threats = None
        try:
            df_known_threats = pd.read_sql_query(p_sql_cmd, con=raw_conn)
        except Exception as e:
            db_write_log(f"get_known_threats failed with error: {e}", 0, "get_known_threats", "")
        return df_known_threats

def get_safe_queries ():
        pg_connection_string = get_connection_string()
        postgres_engine = create_engine(pg_connection_string)
        metadata = MetaData(schema="monitoring")
        raw_conn = postgres_engine.raw_connection()
        p_sql_cmd = """
            select query from monitoring.v_safe_queries
    """
        df_safe_queries = None
        try:
            df_safe_queries = pd.read_sql_query(p_sql_cmd, con=raw_conn)
        except Exception as e:
            db_write_log(f"get_safe_queries failed with error: {e}", 0, "get_safe_queries", "")
        return df_safe_queries