var AWS = require('aws-sdk');
var fs = require('fs');
var im = require('imagemagick');
var s3 = new AWS.S3();

const ORIGIN_DIR_NAME = 'origin';
const CONVERTED_TMPFILE_NAME = '/tmp/converted_tmpfile';

exports.handler = function (event, context, callback) {
    const BUCKET = event.bucket_name;

    var getParams = {
        Bucket: BUCKET,
        Key   : ORIGIN_DIR_NAME + '/' + event.filename
    };

    var params = event.parameter.split('-');
    var size = '';
    var crop = '';
    var gravity = '';
    var match = '';

    for (var i = 0; i < params.length; i++) {
        if (!size) {
            match = params[i].match(/^\d*%?x?\d*%?[\^!<>@]?$/i);
            if (match) {
              size = match[0];
              continue;
            }
        }
        if (!crop) {
            match = params[i].match(/^crop(\d+x\d+\+\d+\+\d+)$/i);
            if (match) {
              crop = match[1];
              continue;
            }
        }
        if (!gravity) {
            match = params[i].match(/^(NorthWest|North|NorthEast|West|Center|East|SouthWest|South|SouthEast)$/i);
            if (match) {
              gravity = match[0];
              continue;
            }
        }
    }
    console.log(size);
    console.log(crop);
    console.log(gravity);

    convertParams = [];
    convertParams.push('-');
    if (size) {
        convertParams.push('-resize');
        convertParams.push(size);
    }
    if (gravity) {
        convertParams.push('-gravity');
        convertParams.push(gravity);
    }
    if (crop) {
        convertParams.push('-crop');
        convertParams.push(crop);
        convertParams.push("+repage");
    }
    convertParams.push(CONVERTED_TMPFILE_NAME);

    s3.getObject(getParams, function (err, data) {
        if (err) { callback(err, 's3 getObject'); }

        var proc = im.convert(convertParams, function (err, stdout, stderr) {
            if (err) { callback(err, 'im convert'); }

            fs.readFile(CONVERTED_TMPFILE_NAME, function (err, converted_data) {
                if (err) { callback(err, converted_data, 'converted tempfile read'); }

                var key = event.parameter + '/' + event.filename;
                s3.putObject({
                    Bucket: BUCKET,
                    Key   : key,
                    Body  : new Buffer(converted_data, 'binary'),
                    ContentType: data.ContentType
                }, function (err, res) {
                    if (err) { callback(err, 's3 putObject'); }

                    callback(null, { location: 'http://' + BUCKET + '.s3-website-ap-northeast-1.amazonaws.com/' + key });
                });
            });
        });

        proc.stdin.setEncoding('binary');
        proc.stdin.write(data.Body, 'binary');
        proc.stdin.end();
    });
};
