# Telemetry

Rivulet includes a built-in, fiber-local telemetry system that records the
execution flow of every request. Each `Rivulet::Operation` and `Rivulet::Step`
is automatically timed via `Rivulet::Telemetry::TimingWrapper`, which is
prepended into every subclass. Database queries are timed through
`Rivulet::Telemetry::SequelExtension`. The resulting tree of nodes is logged
at the end of each request:

```
Completed total_ms=42.3 db_ms=8.1 flow:
Handlers::Posts::Operations::Show (2.1) =>
  Services::Posts::Steps::LoadPost (35.4) =>
    Services::Posts::Steps::Authorize (1.2)
  Handlers::Posts::Steps::BuildResponse (1.1)
```

## Sink Protocol

The telemetry system is extensible through a sink protocol
(`Rivulet::Telemetry::Sink`). A sink receives callbacks for each lifecycle
event:

- `on_start(node, parent)` — called when an operation or step begins.
- `on_stop(node)` — called when it ends, with `duration_ms` and `self_ms`
  already computed.
- `on_db(elapsed_ms)` — called after each database query.
- `on_root(node, total_ms)` — called at the end of the request, after the
  full tree is built.

The default sink is `Rivulet::Telemetry::Sink::Null` (no-op). Apps configure
a custom sink via `config.telemetry.sink` in `config/application.rb`.

## OpenTelemetry

Add the `rivulet-opentelemetry` gem to your application and run
`bundle exec rivulet-otel setup` to wire in OpenTelemetry. The gem provides:

- `Rivulet::OTel::Sink` — implements the sink protocol, emitting one span
  per operation and per step, with correct parent-child nesting via a
  fiber-local span stack. Also records metrics (request count/duration,
  DB queries/duration, step duration) on each callback.
- `Rivulet::OTel::Logger` — replaces the default dry-logger. Each log
  record is emitted as a real OTel log with the current span context
  attached (trace_id, span_id), enabling trace-to-log correlation in
  Grafana. Logs are also written to stdout for local visibility.
- `Rivulet::OTel.configure(service_name:)` — boots the OTel SDK with
  traces, logs, and metrics exporters, gated on
  `OTEL_EXPORTER_OTLP_ENDPOINT` (no-op when unset).

The setup command adds a single `grafana/otel-lgtm` service to
`docker-compose.yml` and wires in the initializer. Grafana is available at
`http://localhost:3000` (admin/admin) with Tempo, Loki, and Prometheus
pre-configured.
