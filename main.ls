require! <[cheerio request fs]>

if not fs.exists-sync(\raw) => fs.mkdir-sync \raw
postmanager = do
  write: (id, data) -> 
    p = @path id
    if !fs.exists-sync("raw/#{p.1}") => fs.mkdir-sync("raw/#{p.1}")
    fs.write-file-sync p.0, data
  exists: (id) -> fs.exists-sync @path(id).0
  path: (id) ->
    id = "#id"
    prefix = id.substring(0,2)
    postfix = id.substring(2)
    return ["raw/#prefix/#postfix", prefix, postfix]

# sample: dir=ask, page=1
fetchlist = (dir, page, cb) ->
  (e,r,b) <- request {
    url: "https://tw.knowledge.yahoo.com/dir/dir?dir=#dir&sid=396540385&cp=#page"
  }, _
  if e or !b or /錯誤編號999/.exec(b) => return setTimeout (-> fetchlist dir,page,cb),parseInt(Math.random!*1000) + 2000
  $ = cheerio.load b
  questions = []
  qtag = $('#ykpclv .bd tr')
  qtag.map (i,e) ->
    if $(e).find("td").length =>
      link = $(e).find("td.subject a").attr("href")
      qid = /qid=(\d+)$/.exec(link).1
      title = $(e).find("td.subject a").text!trim!
      reply = $(e).find("td:last-of-type").text!trim!
      questions.push {title, qid, reply}

  pageinfo = $('#ykpclv .bd tr.info th:first-of-type .pagination .page-info').text!
  pagerange = /顯示\s+(\d+)\s+-\s+(\d+)\s+則/.exec(pageinfo)
  pagerange = [parseInt(pagerange.1), parseInt(pagerange.2)]
  pagecount = /共\s+(\d+)\s+則/.exec pageinfo
  pagecount = parseInt(pagecount.1)
  cb questions, pagerange, pagecount

fetchpost = (dir, item, cb) ->
  (e,r,b) <- request {
    url: "https://tw.knowledge.yahoo.com/question/question?qid=#{item.qid}"
  }, _
  if e or !b or /錯誤編號999/.exec(b) => return setTimeout (-> fetchpost dir, item, cb),parseInt(Math.random!*1000) + 2000
  $ = cheerio.load b
  content = $('#ykpqc_bd .main div').text!
  postmanager.write item.qid, content
  cb!

fetchpost-all = (dir, items, cb) ->
  while true
    if items.length == 0 => return cb!
    item = items.splice(0,1).0
    console.log "#{item.qid} / #{item.title.substring(0,20)}"
    if !postmanager.exists(item.qid) => break
  fetchpost dir, item, -> setTimeout (-> fetchpost-all dir, items, cb), 1000

fetch-next = (dir, callback) ->
  count = 1
  cb2 = ->
    count := count + 1
    fetchlist dir, count, cb
  cb = (qs, pr, pc) ->
    console.log "dir=#dir, #{pr.0} ~ #{pr.1} / #pc"
    if pr.1 >= pc => return setTimeout callback, 1000
    fetchpost-all dir, qs, cb2
    
  fetchlist dir, 1, cb


dirs = <[ask vote solved]>
fetch-dir = ->
  if !dirs.length => return
  dir = dirs.splice(0,1).0
  setTimeout (-> fetch-next dir, fetch-dir), 1000

fetch-dir!
