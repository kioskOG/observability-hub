from flask import Flask, request, jsonify
import logging
from random import randint
import pyroscope
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor

from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# ---------- OTEL Setup ----------
resource = Resource(attributes={
    SERVICE_NAME: "otel-python-app"
})

pyroscope.configure(
    application_name="otel-python-app",
    server_address="http://grafana-alloy.alloy-logs.svc.cluster.local:4041",
    sample_rate=100
)

trace.set_tracer_provider(TracerProvider(resource=resource))
tracer_provider = trace.get_tracer_provider()

otlp_exporter = OTLPSpanExporter(
    endpoint="grafana-alloy.alloy-logs.svc.cluster.local:4317",
    insecure=True,
)

span_processor = BatchSpanProcessor(otlp_exporter)
tracer_provider.add_span_processor(span_processor)

# ---------- Flask App Setup ----------
app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

tracer = trace.get_tracer(__name__)

def generate_metadata():
    current_span = trace.get_current_span()
    span_context = current_span.get_span_context()

    return {
        "trace_id": format(span_context.trace_id, "032x"),
        "span_id": format(span_context.span_id, "016x"),
        "http_target": request.path,
        "http_method": request.method
    }

def log_metadata(metadata):
    logger.info(f"Response metadata: {metadata}")

@app.route("/")
def index():
    metadata = generate_metadata()
    metadata["message"] = "Welcome to OpenTelemetry Instrumented App!"
    log_metadata(metadata)
    return jsonify(metadata)

@app.route("/home")
def manual_tracing():
    with tracer.start_as_current_span("manual_span") as span:
        span.set_attribute("http.target", request.path)
        span.set_attribute("http.method", request.method)
        span.set_attribute("env", "development")

        metadata = generate_metadata()
        metadata["message"] = "This is manually instrumented!"
        metadata["env"] = "Development"
        log_metadata(metadata)
        return jsonify(metadata)

@app.route("/shop")
def auto_tracing():
    metadata = generate_metadata()
    metadata["message"] = "Welcome To Our Online Shopping"
    log_metadata(metadata)
    return jsonify(metadata)

@app.route("/blog")
def blog_metadata():
    metadata = generate_metadata()
    metadata["message"] = "Welcome, Find Latest News Here!"
    log_metadata(metadata)
    return jsonify(metadata)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)