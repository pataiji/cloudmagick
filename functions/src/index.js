"use strict";

const AWS = require("aws-sdk");
const im = require("imagemagick");
const fs = require("fs");
const S3 = new AWS.S3();

const TMP_INPUT_FILE_PATH = "/tmp/inputFile";
const TMP_OUTPUT_FILE_PATH = "/tmp/converted_tmpfile";
const MAX_AGE_SEC = 315360000; // 10 years

const buildS3Params = filename => {
  const originPrefix = process.env.ORIGIN_PREFIX.replace(/^\//, "").replace(
    /\/$/,
    ""
  );
  const encodedKey =
    originPrefix.length > 0 ? originPrefix + "/" + filename : filename;
  return {
    Bucket: process.env.BUCKET_NAME,
    Key: decodeURI(encodedKey)
  };
};

const parseParams = (params, convertParams) => {
  let size,
    crop,
    gravity = false;
  for (var i = 0; i < params.length; i++) {
    if (!size) {
      const match = params[i].match(/^\d*%?x?\d*%?[\^!<>@]?$/i);
      if (match) {
        convertParams.push("-resize");
        convertParams.push(match[0]);
        size = true;
        continue;
      }
    }
    if (!crop) {
      const match = params[i].match(/^crop(\d+x\d+\+\d+\+\d+)$/i);
      if (match) {
        convertParams.push("-crop");
        convertParams.push(match[1]);
        convertParams.push("+repage");
        crop = true;
        continue;
      }
    }
    if (!gravity) {
      const match = params[i].match(
        /^(?:NorthWest|North|NorthEast|West|Center|East|SouthWest|South|SouthEast)$/i
      );
      if (match) {
        convertParams.push("-gravity");
        convertParams.push(match[0]);
        gravity = true;
        continue;
      }
    }
  }
  return convertParams;
};

const buildConvertParams = event => {
  let convertParams = [];

  convertParams.push(TMP_INPUT_FILE_PATH);
  convertParams.push("-auto-orient");
  const params = decodeURIComponent(event.pathParameters.parameter).split("-");
  convertParams = parseParams(params, convertParams);
  convertParams.push(TMP_OUTPUT_FILE_PATH);

  console.log(convertParams);

  return convertParams;
};

const convert = (event, callback) => {
  const S3Params = buildS3Params(event.pathParameters.filename);
  S3.getObject(S3Params, (err, data) => {
    if (err) {
      callback(err, err.stack);
    }

    fs.writeFile(TMP_INPUT_FILE_PATH, Buffer.from(data.Body), err => {
      if (err) {
        callback(err, err.stack);
      }

      const convertParams = buildConvertParams(event);
      im.convert(convertParams, (err, stdout, stderr) => {
        if (err) {
          callback(err, err.stack);
        }

        fs.readFile(TMP_OUTPUT_FILE_PATH, (err, convertedData) => {
          if (err) {
            callback(err, convertedData);
          }

          const expires = new Date(
            Date.now() + MAX_AGE_SEC * 1000
          ).toUTCString();
          const etag = convertedData.length + Date.parse(data.LastModified);

          callback(null, {
            isBase64Encoded: true,
            statusCode: 200,
            headers: {
              "Content-Type": data.ContentType,
              "Cache-Control": "max-age=" + MAX_AGE_SEC,
              Expires: expires,
              ETag: etag
            },
            body: Buffer.from(convertedData).toString("base64")
          });
        });
      });
    });
  });
};

exports.handler = (event, context, callback) => {
  convert(event, callback);
};
