import Config

config :mini_repo,
  port: 4000,
  url: "http://localhost:4000"

#store = {MiniRepo.Store.Local, root: "/code/data"}

config :ex_aws,
  access_key_id: [{:awscli, "default", 30}, {:system, "AWS_ACCESS_KEY_ID"},],
  secret_access_key: [{:awscli, "default", 30},{:system, "AWS_SECRET_ACCESS_KEY"}],
  region: "eu-west-1",
  json_codec: Jason

store =
  {MiniRepo.Store.S3,
    bucket: "prima-mini-repo",
    options: [region: "eu-west-1"]
  }

config :mini_repo,
  auth_token: "secret",
  store: [
    bucket: "prima-mini-repo",
    options: [region: "eu-west-1"]
  ],
  repositories: [
    test_repo: [
      private_key: File.read!(Path.expand("../priv/test_repo_private.pem", __DIR__)),
      public_key: File.read!(Path.expand("../priv/test_repo_public.pem", __DIR__)),
      store: store
    ],
    hexpm_mirror: [
      store: store,
      upstream_name: "hexpm",
      upstream_url: "https://repo.hex.pm",

      on_demand: true,

      # 5min
      sync_interval: 5 * 60 * 1000,
      sync_opts: [max_concurrency: 5, timeout: String.to_integer(System.get_env("MIRROR_TIMEOUT", "30000"))],

      # https://hex.pm/docs/public_keys
      upstream_public_key: """
      -----BEGIN PUBLIC KEY-----
      MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApqREcFDt5vV21JVe2QNB
      Edvzk6w36aNFhVGWN5toNJRjRJ6m4hIuG4KaXtDWVLjnvct6MYMfqhC79HAGwyF+
      IqR6Q6a5bbFSsImgBJwz1oadoVKD6ZNetAuCIK84cjMrEFRkELtEIPNHblCzUkkM
      3rS9+DPlnfG8hBvGi6tvQIuZmXGCxF/73hU0/MyGhbmEjIKRtG6b0sJYKelRLTPW
      XgK7s5pESgiwf2YC/2MGDXjAJfpfCd0RpLdvd4eRiXtVlE9qO9bND94E7PgQ/xqZ
      J1i2xWFndWa6nfFnRxZmCStCOZWYYPlaxr+FZceFbpMwzTNs4g3d4tLNUcbKAIH4
      0wIDAQAB
      -----END PUBLIC KEY-----
      """
    ]
  ]
