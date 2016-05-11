css_md5=$(md5sum public/css/crispr.css | \
sed -e 's|  public/css/crispr.css||' )

js_md5=$(md5sum public/javascripts/crisprapp.js | \
sed -e 's|  public/javascripts/crisprapp.js||' )

sed -i -r -e "s|crisprapp.js\?v[a-z0-9]+|crisprapp.js?v${js_md5}|" views/layouts/main.tt
sed -i -r -e "s|crispr.css\?v[a-z0-9]+|crispr.css?v${css_md5}|" views/layouts/main.tt
