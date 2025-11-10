# エラークラスを確実にロード
# ApplicationControllerより前にロードされるように、初期化ファイルでrequire
require_relative "../../app/errors/application_errors"

