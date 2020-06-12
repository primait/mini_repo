import Config

config :mini_repo,
  port: String.to_integer(System.get_env("PORT", "4000")),
  url: System.get_env("MINI_REPO_URL", "http://localhost:4000")

repo_name = String.to_atom(System.get_env("MINI_REPO_REPO_NAME", "test_repo"))

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

private_key =
  System.get_env("MINI_REPO_PRIVATE_KEY") ||
    File.read!(Path.join([:code.priv_dir(:mini_repo), "test_repo_private.pem"]))

public_key =
  System.get_env("MINI_REPO_PUBLIC_KEY") ||
    File.read!(Path.join([:code.priv_dir(:mini_repo), "test_repo_public.pem"]))

auth_token =
  System.get_env("MINI_REPO_AUTH_TOKEN") ||
    raise """
    Environment variable MINI_REPO_AUTH_TOKEN must be set.

    You can generate secret e.g. with this:

        iex> length = 32
        iex> :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
        "Xyf..."
    """

#store = {MiniRepo.Store.Local, root: "/code/data"}

config :mini_repo,
  auth_token: System.fetch_env!("MINI_REPO_AUTH_TOKEN"),
  store: [
    bucket: "prima-mini-repo",
    options: [region: "eu-west-1"]
  ],
  repositories: [
    "#{repo_name}": [
      private_key: private_key,
      public_key: public_key,
      store: store
    ],
    hexpm_mirror: [
      store: store,
      upstream_name: "hexpm",
      upstream_url: "https://repo.hex.pm",

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
      """,

      on_demand: true,

      # 5min
      sync_interval: 5 * 60 * 1000
    ]
  ]
