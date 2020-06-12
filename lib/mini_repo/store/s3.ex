defmodule MiniRepo.Store.S3 do
  @moduledoc """
  S3 storage.

  ## Options

    * `:bucket` - the S3 bucket
    * `:options` - the S3 request options.

      Some avaialble options are listed in:
      https://github.com/ex-aws/ex_aws/blob/master/lib/ex_aws/config.ex

  ## Usage

  Add to `config/releases.exs`:

      config :ex_aws,
        access_key_id: System.fetch_env!("MINI_REPO_S3_ACCESS_KEY_ID"),
        secret_access_key: System.fetch_env!("MINI_REPO_S3_SECRET_ACCESS_KEY"),
        json_codec: Jason

      store =
        {MiniRepo.Store.S3,
         bucket: System.fetch_env!("MINI_REPO_S3_BUCKET"),
         options: [
           region: System.fetch_env!("MINI_REPO_S3_REGION")]
         }

  And configure your repositories with the given store, e.g.:

      config :mini_repo,
        repositories: [
          myrepo: [
            store: store,
            # ...
          ]

  Finally, by default, the files stored on S3 are not publicly accessible.
  You can enable public access by setting the following bucket policy in your
  bucket's properties:

  ```json
  {
      "Version": "2008-10-17",
      "Statement": [
          {
              "Sid": "AllowPublicRead",
              "Effect": "Allow",
              "Principal": {
                  "AWS": "*"
              },
              "Action": "s3:GetObject",
              "Resource": "arn:aws:s3:::minirepo/*"
          }
      ]
  }
  ```

  Since we're storing files on S3, in order to access the repo we can use the publicly
  accessible URL of the bucket:

      mix hex.repo add myrepo https://<bucket>.s3.<region>.amazonaws.com/repos/myrepo --public-key $MINI_REPO_PUBLIC_KEY

  See [Amazon S3 docs](https://docs.aws.amazon.com/s3/index.html) for more information.

  You may also want to use a minimal IAM policy for the IAM user accessing the
  S3 bucket:

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "VisualEditor0",
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Resource": [
          "arn:aws:s3:::minirepo",
          "arn:aws:s3:::minirepo/*"
        ]
      }
    ]
  }
  ```
  """

  @behaviour MiniRepo.Store

  alias ExAws.S3

  defstruct [:bucket, :options]

  @impl true
  def put(key, value) do
    key = Path.join(List.wrap(key))
    request = S3.put_object(s3_bucket(), key, value, s3_options())

    with {:ok, _} <- ExAws.request(request) do
      :ok
    end
  end

  @impl true
  def fetch(key) do
    key = Path.join(List.wrap(key))
    request = S3.get_object(s3_bucket(), key, s3_options())

    case ExAws.request(request, s3_options()) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      other ->
        other
    end
  end

  @impl true
  def exists?(key) do #TODO controllare output che non si capisce un cazzo
    key = Path.join(List.wrap(key))
    request = S3.head_object(s3_bucket(), key, s3_options())

    case ExAws.request(request) do
      {:ok, true} ->
        {:ok, true}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      other ->
        other
    end
  end

  @impl true
  def delete(key) do
    key = Path.join(List.wrap(key))
    request = S3.delete_object(s3_bucket(), key, s3_options())

    with {:ok, _} <- ExAws.request(request) do
      :ok
    end
  end

  defp s3_bucket(), do: Application.get_env(:mini_repo, :store)[:bucket]

  defp s3_options(), do: Application.get_env(:mini_repo, :store)[:options]

end
