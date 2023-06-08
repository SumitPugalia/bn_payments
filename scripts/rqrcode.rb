require 'rqrcode'

qrcode_content = ARGV[0]
qrcode = RQRCode::QRCode.new(qrcode_content)
image = qrcode.as_png(
          resize_gte_to: false,
          resize_exactly_to: false,
          fill: 'white',
          color: 'black',
          size: 284,
          border_modules: 4,
          module_px_size: 6,
          file: nil # path to write
          )

puts image.to_s