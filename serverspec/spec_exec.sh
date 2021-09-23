while getopts alx optKey; do
  case "$optKey" in
    a)
			# ~/.ssh/configに新規追加
      ;;
    l)
    #  ~/.ssh/configの一覧を表示
      ;;
    x)
    #  テスト実行
      ;;
    '-h'|'--help'|* )
      usage
      ;;
  esac
done

