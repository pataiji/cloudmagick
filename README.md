## Install

<a href="https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=cloudmagick&amp;templateURL=https://s3-ap-northeast-1.amazonaws.com/public.pataiji.com/cloudmagick-v0.1.1.yml" target="_blank">
<img alt="Launch Stack" src="https://cdn.rawgit.com/buildkite/cloudformation-launch-stack-button-svg/master/launch-stack.svg">
</a>

## Development

#### Deploy

set environments
```
CLOUD_MAGICK_TEMPLATE_BUCKET_NAME
CLOUD_MAGICK_STACK_NAME
CLOUD_MAGICK_BUCKET_NAME
CLOUD_MAGICK_ORIGIN_PREFIX
CLOUD_MAGICK_CUSTOM_DOMAIN_NAME
CLOUD_MAGICK_ACM_CERTIFICATE_ARN
CLOUD_MAGICK_LOG_BUCKET_NAME
CLOUD_MAGICK_LOG_PREFIX
CLOUD_MAGICK_PRICE_CLASS
CLOUD_MAGICK_MIN_TTL
CLOUD_MAGICK_MAX_TTL
```

and run

```
$ bin/deploy
```

#### Release

set environments
```
CLOUD_MAGICK_RELEASE_BUCKET_NAME
VERSION
```

and run

```
$ bin/release
```
