json.array!(@crawlers) do |crawler|
  json.extract! crawler, :id
  json.url crawler_url(crawler, format: :json)
end
