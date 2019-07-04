## v0.1.4 - 2019-07-04

- Changed
  - Change runtime of Lambda to nodejs8.10 from nodejs6.10
  - Change default price class of CloudFront to PriceClass_All from PriceClass_200
- Fixed
  - Use `Buffer.from` instead of `new Buffer`

## v0.1.3 - 2018-08-01

- feature
  - Support multi-byte filename
- bug fixes
  - Fix default max-age

## v0.1.2 - 2017-09-29

- feature
  - Add headers for cache

## v0.1.1 - 2017-09-18

- bug fixes
  - Fix parsing url encoded parameter
  - Fix parsing originPrefix
