const slogan = 'lua-resty-router - Elegant, performant and productive router for Openresty'
const colorizedslogan = require('gradient-string')([
  { color: '#42d392', pos: 0 },
  { color: '#42d392', pos: 0.1 },
  { color: '#647eff', pos: 1 }
])(slogan)



console.log(`
const defaultBanner = '${slogan}'
const gradientBanner = ${JSON.stringify(colorizedslogan)}
export { defaultBanner, gradientBanner }
  `)
