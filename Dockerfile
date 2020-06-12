FROM prima/elixir:1.10.2-1
USER app

WORKDIR /code

COPY entrypoint /entrypoint

ENTRYPOINT ["/entrypoint"]
