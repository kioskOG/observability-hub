"""
This application is used to register and authenticate users with Prometheus and OpenTelemetry tracing support.
"""

import os
import time
import logging
from flask import Flask, request, jsonify
from flask_mysqldb import MySQL
import MySQLdb.cursors
import mysql.connector
import pymysql

from prometheus_client import Summary, Counter, Gauge, generate_latest

# --- OTEL Setup ---
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor

resource = Resource(attributes={
    SERVICE_NAME: "auth-service"
})

trace.set_tracer_provider(TracerProvider(resource=resource))
tracer_provider = trace.get_tracer_provider()
otlp_exporter = OTLPSpanExporter(
    endpoint="grafana-alloy.alloy-logs.svc.cluster.local:4317",
    insecure=True
)
span_processor = BatchSpanProcessor(otlp_exporter)
tracer_provider.add_span_processor(span_processor)
tracer = trace.get_tracer(__name__)

# --- Flask Setup ---
server = Flask(__name__)
FlaskInstrumentor().instrument_app(server)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

MYSQL_SERVER_ENDPOINT = os.environ['MYSQL_SERVER_ENDPOINT']
MYSQL_SERVER_USERNAME = os.environ['MYSQL_SERVER_USERNAME']
MYSQL_SERVER_PASSWORD = os.environ['MYSQL_SERVER_PASSWORD']
MYSQL_SERVER_DATABASE = os.environ['MYSQL_SERVER_DATABASE']

server.config['MYSQL_HOST'] = MYSQL_SERVER_ENDPOINT
server.config['MYSQL_USER'] = MYSQL_SERVER_USERNAME
server.config['MYSQL_PASSWORD'] = MYSQL_SERVER_PASSWORD
server.config['MYSQL_DB'] = MYSQL_SERVER_DATABASE

mysqlVar = MySQL(server)

# Prometheus metrics
REQUEST_TIME = Summary('login_request_processing_seconds', 'Time spent processing login request')
REQUEST_COUNT = Counter('login_request_count', 'Number of login requests')
IN_PROGRESS = Gauge('login_in_progress_requests', 'In-progress login requests')
REQUEST_FAILURES = Counter('login_request_failures', 'Number of failed login requests')


def log_trace_metadata(message):
    span = trace.get_current_span()
    context = span.get_span_context()
    metadata = {
        "trace_id": format(context.trace_id, "032x"),
        "span_id": format(context.span_id, "016x"),
        "http_target": request.path,
        "http_method": request.method,
        "message": message
    }
    logger.info(metadata)


@server.route('/auth/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': 'text/plain; charset=utf-8'}


@server.route('/api/v1/auth/login', methods=['GET'])
@REQUEST_TIME.time()
def login():
    REQUEST_COUNT.inc()
    IN_PROGRESS.inc()

    with tracer.start_as_current_span("auth_login"):
        username = request.json['username']
        password = request.json['password']
        try:
            connection = pymysql.connect(
                host=MYSQL_SERVER_ENDPOINT,
                user=MYSQL_SERVER_USERNAME,
                password=MYSQL_SERVER_PASSWORD,
                database=MYSQL_SERVER_DATABASE,
                cursorclass=pymysql.cursors.DictCursor
            )
        except pymysql.err.OperationalError:
            REQUEST_FAILURES.inc()
            IN_PROGRESS.dec()
            log_trace_metadata("MySQL connection failed")
            return jsonify({"msg": "Unknown MySQL server host"}), 500

        cursor = connection.cursor()
        cursor.execute('SELECT * FROM users WHERE username = %s AND password = %s', (username, password))
        account = cursor.fetchone()
        IN_PROGRESS.dec()

        if account is None:
            REQUEST_FAILURES.inc()
            log_trace_metadata("Invalid credentials")
            return jsonify({'Msg': 'Wrong Credentials!'}), 403

        log_trace_metadata("Login successful")
        return jsonify({"username": account['username'], "password": account['password'], "email": account['email']}), 200


@server.route('/api/v1/auth/user', methods=['GET'])
def usercheck():
    username = request.json['username']
    with tracer.start_as_current_span("auth_usercheck"):
        try:
            cursor = mysqlVar.connection.cursor(MySQLdb.cursors.DictCursor)
        except MySQLdb.OperationalError:
            log_trace_metadata("MySQL error on user check")
            return jsonify({"msg": "Unknown MySQL server host"}), 500

        cursor.execute('SELECT * FROM users WHERE username = %s', [username])
        account = cursor.fetchone()
        if account is None:
            log_trace_metadata("User not found")
            return jsonify({'Msg': 'username doesnot exists !!'}), 403

        log_trace_metadata("User exists")
        return jsonify({"username": account['username']}), 200


@server.route('/api/v1/auth/register', methods=['POST'])
def register():
    REQUEST_COUNT.inc()
    IN_PROGRESS.inc()

    with tracer.start_as_current_span("auth_register"):
        email = request.json['email']
        password = request.json['password']
        username = request.json['username']
        try:
            mydb = mysql.connector.connect(
                host=MYSQL_SERVER_ENDPOINT,
                user=MYSQL_SERVER_USERNAME,
                password=MYSQL_SERVER_PASSWORD,
                database=MYSQL_SERVER_DATABASE
            )
        except mysql.connector.errors.DatabaseError:
            REQUEST_FAILURES.inc()
            IN_PROGRESS.dec()
            log_trace_metadata("MySQL connection failed on register")
            return jsonify({"msg": "Unknown MySQL server host"}), 500

        mycursor = mydb.cursor()
        try:
            mycursor.execute('INSERT INTO users (email,password,username) VALUES(%s, %s, %s)', (email, password, username))
        except mysql.connector.Error as my_error:
            if "Duplicate" in my_error.msg:
                REQUEST_FAILURES.inc()
                IN_PROGRESS.dec()
                log_trace_metadata("Duplicate registration")
                return jsonify({"msg": "user exists"}), 500
        mydb.commit()
        IN_PROGRESS.dec()
        log_trace_metadata("User registered")
        return jsonify({"email": email}), 200


if __name__ == "__main__":
    server.run(debug=True, host="0.0.0.0", port=5000)
