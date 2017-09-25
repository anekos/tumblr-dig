# tumblr-dig
Dig tumblr

# Usage

## dig dashboard

```
$ bundle exec ruby tumblr-dig.rb --oauth-config ~/my-oauth_config.json --format chrysoberyl --posts 100
```

## reglog

```
bundle exec ruby tumblr-dig.rb --oauth-config ~/my-oauth_config.json --reblog "${POST_ID}/${REBLOG_KEY}"
```
