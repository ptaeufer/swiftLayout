#!/bin/sh

init_res() {
    res=$(dirname -- "$R")
    mkdir -p $res/{images/Images.xcassets,layout,strings/Base.lproj,styles,values}

    images=$res/images/Images.xcassets/Contents.json
    touch images
    echo "{\"info\" : {\"version\" : 1,\"author\" : \"xcode\"}}" >> $images

    touch $res/strings/Base.lproj/Localizable.strings

    styles=$res/styles/styles.swift
    touch styles
    echo "import UIKit" >> $styles
    echo "class Style : Resource {" >> $styles
    echo "" >> $styles
    echo "  lazy var Default : Style = [" >> $styles
    echo "      \"textColor\" : UIColor.white," >> $styles
    echo "  ]" >> $styles
    echo "}" >> $styles

    colors=$res/values/colors.swift
    touch colors
    echo "import Foundation" >> $colors
    echo "class Color : Resource {" >> $colors
    echo "" >> $colors
    echo "  lazy var primary = \"#000000\""; >> $colors
    echo "}" >> $colors

    urls=$res/values/urls.swift
    touch urls
    echo "import Foundation" >> $urls
    echo "class Url : Resource {" >> $urls
    echo "" >> $urls
    echo "  lazy var api = \"https://www.myApi.com/post/%d\""; >> $urls
    echo "}" >> $urls

    fonts=$res/values/fonts.swift
    touch fonts
    echo "import Foundation" >> $fonts
    echo "class Font : Resource {" >> $fonts
    echo "" >> $fonts
    echo "  lazy var api = \"https://www.myApi.com/post/%d\""; >> $fonts
    echo "}" >> $fonts

}

embed_newline()
{
    local p="$1"
    shift
    for i in "$@"; do
        p="$p"$'\n'"$i"
    done
    echo "$p"
}

write_enum()
{

    echo "" >> $R
#echo "extension R {" >> $R
    echo "" >> $R
    echo "    enum $1 : String {" >> $R
    echo "" >> $R
    local_variable="${2}"
    shift
    local _contents=("${@}")
    for case in ${_contents[@]}; do
    echo "        case "$case >> $R
    done
    if [ -z "$_contents" ]
    then
    echo "        case none" >> $R
    fi
    echo "" >> $R
    echo "        func get<T>() -> T! {" >> $R
    echo "            return self.rawValue as! T" >> $R
    echo "        }" >> $R
    echo "" >> $R
    echo "    }" >> $R
    echo "" >> $R

#echo "}" >> $R
}


basePath="${SRCROOT}"
R=$(find ${basePath}/*/res -name "R.swift" | head -n 1)

if [ ! -z "$R" -a "$R" != " " ]; then

    if [ -z "$(cat $R)" ]
    then
        init_res
    fi

    tmpfile=`mktemp`
    echo "import Foundation" >> $tmpfile
    echo "" >> $tmpfile
    echo "class R{" >> $tmpfile
    for file in $(find ${basePath} -name "*.swift"); do
    for name in $(cat $file | grep "class" | sed -n 's/.*class *\(.*\) *: *RawResource.*/\1/p' | sort -u); do
    echo "    static let $(echo "$name" | awk '{print tolower($0)}') = $name();" >> $tmpfile
    done
    done
    echo "" >> $tmpfile
    mv $tmpfile $R
#echo "}" >> $tmpfile

    START_TIME="$(date +%s)"
    tmpfile=`mktemp`
    echo "" >> $tmpfile
    echo "@objcMembers" >> $tmpfile
    echo "class ResourcePool : NSObject{" >> $tmpfile
    for file in $(find ${basePath} -name "*.swift"); do
    for name in $(cat $file | grep "class" | sed -n 's/.*class *\(.*\) *: *Resource.*/\1/p' | sort -u); do
    echo "    static let $(echo "$name" | awk '{print tolower($0)}') = $name();" >> $tmpfile
    echo "" >> $R
#echo "extension R {" >> $R
    echo "" >> $R
    sed -i '' -e 's/ let / lazy var /g' $file
    contents=$(cat $file | grep "lazy var" | sed -n 's/.*lazy var *\([a-zA-Z0-9_\-]*\) *.*=.*/\1/p')
    echo "    enum $(echo "$name" | awk '{print tolower($0)}') : String {" >> $R
    echo "" >> $R
    for _name in $contents; do
    echo "        case "$_name >> $R
    done

    if [ -z "${contents[@]}" ]
    then
    echo "        case none" >> $R
    fi

    echo "" >> $R

    echo "        func get<T>() -> T! {" >> $R
    echo "            return ResourcePool.$(echo "$name" | awk '{print tolower($0)}').value(forKey: self.rawValue) as! T" >> $R
    echo "        }" >> $R

    echo "    }" >> $R
    echo "" >> $R
#    echo "}" >> $R

    done
    done

    FINISH_TIME="$(date +%s)"
    DURATION="$((FINISH_TIME-START_TIME))"
    echo "Parsing Resources: took $DURATION s."



    # find layouts
    START_TIME="$(date +%s)"
    contents=""
    echo "" >> $R
    echo "    enum layout {" >> $R
    for file in $(find ${basePath}/ -name "*.swift"); do
    for name in $(cat $file | grep "class"| sed -n 's/.*class *\(.*\) *: *Layout .*/\1/p' | sort -u); do
    echo "        static let $(echo "$name")_internal = $name();" >> $tmpfile
    echo "        static let $(echo "$name") = ResourcePool.$(echo "$name")_internal;" >> $R
    #contents=$contents" $name"
    done
    done
    echo "" >> $R
    echo "    }" >> $R
    # contents=$(find ${basePath}/res/layouts -name "*.swift" | sed 's!.*/!!' | sed 's/\.[^.]*$//')
    #write_enum "layout" $contents
    FINISH_TIME="$(date +%s)"
    DURATION="$((FINISH_TIME-START_TIME))"
    echo "Parsing Layout: took $DURATION s."


    # find ids
    START_TIME="$(date +%s)"
    contents=""
    for file in $(find ${basePath} -name "*.swift"); do
    for name in $(cat $file | grep "R\.id\."| sed 's/.*R\.id\.\([a-zA-Z0-9_\-]*\).*/\1/' | sort -u); do
    contents=$contents" $name"
    done
    done
    write_enum "id" $( embed_newline $contents | sort -u)
    FINISH_TIME="$(date +%s)"
    DURATION="$((FINISH_TIME-START_TIME))"
    echo "Parsing Ids: took $DURATION s."


    # find events
    START_TIME="$(date +%s)"
    contents=""
    for file in $(find ${basePath} -name "*.swift"); do
    for name in $(cat $file | grep "R\.event\." | grep -v "func" | grep -v "R\.event\.[a-zA-Z0-9_\-]*\."| sed 's/.*R\.event\.\([a-zA-Z0-9_\-]*\).* as \([a-zA-Z0-9_\-]*\).*/\1\(\2)/' | sed 's/.*R\.event\.\([a-zA-Z0-9_\-]*\).*/\1/'); do
    contents=$contents" $name"
    done
    done

    contents=$( embed_newline $contents | sort -u)
    echo "" >> $R
# echo "extension R {" >> $R
    echo "" >> $R
    echo "    enum event {" >> $R
    echo "" >> $R
    for case in $contents; do
    echo "        case "$case >> $R
    done
    if [ -z "$contents" ]
    then
    echo "        case none" >> $R
    fi
    echo "" >> $R

    echo "        enum plain : String {" >> $R
    echo "" >> $R
    for case in $contents; do
    plainCase=$(echo $case | sed 's/\(.*\)(.*)/\1/')
    echo "            case "$plainCase >> $R
    done
    if [ -z "$contents" ]
    then
    echo "            case none" >> $R
    fi
    echo "" >> $R
    echo "        }" >> $R
    echo "" >> $R
    echo "        var plainEvent : R.event.plain {" >> $R
    echo "            switch self {" >> $R
    for case in $contents; do
    plainCase=$(echo $case | sed 's/\(.*\)(.*)/\1/')
    echo "                case ."$plainCase": return R.event.plain."$plainCase >> $R
    done
    if [ -z "$contents" ]
    then
    echo "                case .none : return R.event.plain.none" >> $R
    fi
    echo "            }" >> $R
    echo "        }" >> $R
    echo "" >> $R
    echo "    }" >> $R
    echo "" >> $R
# echo "}" >> $R



    FINISH_TIME="$(date +%s)"
    DURATION="$((FINISH_TIME-START_TIME))"
    echo "Parsing Events: took $DURATION s."

    # find assets
    START_TIME="$(date +%s)"
    contents=$(find ${basePath} -type d -name "*.imageset" | sed 's!.*/!!' | sed 's/\.[^.]*$//')
    write_enum "image" $contents

    FINISH_TIME="$(date +%s)"
    DURATION="$((FINISH_TIME-START_TIME))"
    echo "Parsing Images: took $DURATION s."

    # find strings
    START_TIME="$(date +%s)"
    contents=""
    for file in $(find ${basePath} -name "*.strings"); do
    for name in $(cat $file | sed -n 's/ *\([a-zA-Z0-9_\-]*\) *=.*/\1/p' | sed -e 's/\.one//g' | sed -e 's/\.other//g'); do
    contents=$contents" $name"
    done
    done
    write_enum "string" $( embed_newline $contents | sort -u)

    FINISH_TIME="$(date +%s)"
    DURATION="$((FINISH_TIME-START_TIME))"
    echo "Parsing Strings: took $DURATION s."


    echo "}" >> $R

    echo "}" >> $tmpfile

    echo $(cat $tmpfile) >> $R
    echo "extension Dictionary where Iterator.Element == (key: String, value: Any) { mutating func extend(_ ext : [String:Any]) -> Dictionary<String,Any> { self.merge(ext) { (_, new) in new }; return self; } }" >> $R
    echo "class RawResource : NSObject {typealias Style = [String:Any]; }; @objcMembers class Resource : NSObject { typealias Style = [String:Any]; override init() {}}" >> $R

    echo $(cat $(find ${basePath}/*/swiftLayout -name "Extensions" | head -n 1)) >> $R

fi


