struct Healthcheck {
  1: bool ok,
  2: string message
}

service Health {
  Healthcheck check()
}

