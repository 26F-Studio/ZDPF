require("Zenitha")
ZENITHA.setAppName('ZMP')
ZENITHA.setFirstScene('manager')
ZENITHA.setVersionText("v1.0")
ZENITHA.globalEvent.drawCursor=NULL
ZENITHA.globalEvent.clickFX=NULL
SCR.setSize(1600,1000)
STRING.install()

local TNS=20
-- local thumbnailThres=2e6 -- 2MB

---@class ImageFile
---@field file love.File
---@field fullPath string
---@field fileName string
---@field fileSize number
---@field width number
---@field height number
---@field picSize number total picSize
---@field thumbnail love.Canvas size up to TNSxTNS
---@field sizeStr string "1.00 MB"
---@field pixelStr string "1920 x 1080"
---@field discard boolean

local files={} ---@type ImageFile[]
local filePathSet={} ---@type Set<string>

local sortModes={'fileSize','picSize'}
local sortMode='fileSize'
local sortFunc={} ---@type Map<fun(a:ImageFile, b:ImageFile):boolean>
function sortFunc.fileSize(a,b)
    return a.fileSize<b.fileSize
end
function sortFunc.picSize(a,b)
    return a.picSize<b.picSize
end

local mode='explore'
local state={
    explore={
        scroll=0,
    },
    filter={
        dupPairs={},---@type {[1]:ImageFile, [2]:ImageFile}[]
        checking=nil,
    },
}

local function enterFilterMode()
    mode='filter'
    state.filter.dupPairs={}
    state.filter.checking=nil
    for i=1,#files-1 do
        local f1,f2=files[i],files[i+1]
        if MATH.between(f1[sortMode]/f2[sortMode],0.999,1.001) then
            table.insert(state.filter.dupPairs,{f1,f2})
        end
    end
    if state.filter.dupPairs[1] then
        state.filter.checking=1
    end
end

---@type Zenitha.Scene
local scene={}
function scene.keyDown(key,rep)
    if rep then return true end
    if mode=='explore' then
        if key=='tab' then
            sortMode=TABLE.next(sortModes,sortMode) or sortModes[1]
        elseif key=='up' then
            state.explore.scroll=math.max(state.explore.scroll-1,0)
        elseif key=='down' then
            state.explore.scroll=MATH.clamp(state.explore.scroll+1,0,math.max(math.ceil((#files+1)/6)-3,0))
        elseif key=='delete' then
            if love.keyboard.isDown('lctrl','rctrl') then
                files={}
                filePathSet={}
                state.explore.scroll=0
            else
                local output=""
                for i=#files,1,-1 do
                    if files[i].discard then
                        filePathSet[files[i].fullPath]=nil
                        output=output..('del /s /q "$1"'):repD(files[i].fileName).."\n"
                        table.remove(files,i)
                    end
                end
                if #output>0 then
                    love.system.setClipboardText(output)
                    MSG.new('check',"Batch code copied to clipboard")
                    scene.keyDown('down')
                else
                    MSG.new('warn',"No files selected to delete")
                end
            end
        elseif key=='space' then
            table.sort(files,sortFunc[sortMode])
        elseif key=='return' then
            if #files<2 then
                MSG.new('warn',"Filtering need 2 images")
            else
                table.sort(files,sortFunc[sortMode])
                enterFilterMode()
            end
        end
    elseif mode=='filter' then
        if key=='return' then
            mode='explore'
            state.explore.scroll=0
        elseif state.filter.checking then
            if key=='up' then
                if state.filter.checking then
                    state.filter.checking=math.max(state.filter.checking-1,1)
                end
            elseif key=='down' then
                if state.filter.checking then
                    state.filter.checking=math.min(state.filter.checking+1,#state.filter.dupPairs)
                end
            elseif key=='left' then
                local img=state.filter.dupPairs[state.filter.checking][1]
                img.discard=not img.discard
            elseif key=='right' then
                local img=state.filter.dupPairs[state.filter.checking][2]
                img.discard=not img.discard
            end
        end
    end
    return true
end
function scene.fileDrop(file)
    if mode~='explore' then
        MSG.new('warn',"You can only add images in explore mode")
        return
    end
    local path=file:getFilename()
    if filePathSet[path] then return end
    filePathSet[path]=true

    local suc,imgData=pcall(love.image.newImageData,file:read('data'))
    if not suc then
        MSG.new('error',"Failed to load image: "..path)
        return
    end
    local w,h=imgData:getDimensions()
    local thumbnailScale=math.min(TNS/w,TNS/h,1)
    local thumbnail=GC.newCanvas(w*thumbnailScale,h*thumbnailScale)
    thumbnail:setFilter('nearest','nearest')
    GC.setCanvas(thumbnail)
    GC.draw(GC.newImage(imgData),0,0,0,thumbnailScale)
    GC.setCanvas()
    table.insert(files,{
        file=file,
        fileSize=file:getSize(),
        width=w,
        height=h,
        picSize=w*h,

        sizeStr=STRING.fileSize(file:getSize()),
        pixelStr=w.." x "..h,
        fullPath=path,
        fileName=path:match('.+\\(.+)$') or "?",
        thumbnail=thumbnail,
        discard=false,
    })
    imgData:release()
    collectgarbage()
end
local GC=GC
function scene.draw()
    if #files>0 then
        if mode=='explore' then
            FONT.set(35)
            GC.print("Sort: "..sortMode,50,5)

            GC.translate(50,50)
            FONT.set(25)
            GC.setLineWidth(3)
            local s=state.explore.scroll*6+1
            local e=math.min(s+17,#files)
            -- Screen: 1600x1000; Image: 240x240
            for i=s,e do
                local f=files[i]
                if f.discard then
                    GC.setColor(.42,.42,.42)
                    GC.mDraw(f.thumbnail,125,125)
                    GC.setColor(1,.26,.26)
                    GC.line(5,5,245,245)
                    GC.line(5,245,245,5)
                    GC.setColor(1,1,1)
                else
                    GC.setColor(1,1,1)
                    GC.mDraw(f.thumbnail,125,125,0,240/TNS)
                end
                GC.print(f.sizeStr,5,245)
                GC.print(f.pixelStr,5,270)
                GC.setColor(.42,.42,.42)
                GC.rectangle('line',5,5,240,240)
                if i%6>0 then
                    GC.translate(250,0)
                else
                    GC.translate(-1250,310)
                end
            end
        elseif mode=='filter' then
            if state.filter.checking then
                FONT.set(60)
                GC.mStr(state.filter.checking,800,410)
                GC.line(760,500,840,500)
                GC.mStr(#state.filter.dupPairs,800,510)
                FONT.set(35)
                GC.mStr(sortMode,800,600)
                -- Each Side: 800x1000
                FONT.set(30)
                local pair=state.filter.dupPairs[state.filter.checking]
                for i=1,2 do
                    local f=pair[i]
                    local k=math.min(600/f.thumbnail:getWidth(),750/f.thumbnail:getHeight())
                    if f.discard then
                        GC.setColor(.62,.62,.62)
                        GC.mDraw(f.thumbnail,400,500,0,k)
                        GC.setColor(1,.26,.26)
                        GC.setLineWidth(10)
                        GC.line(100,175,700,825)
                        GC.line(100,825,700,175)
                        GC.setColor(1,1,1)
                    else
                        GC.setColor(1,1,1)
                        GC.mDraw(f.thumbnail,400,500,0,k)
                    end
                    GC.setLineWidth(6)
                    GC.rectangle('line',100,125,600,750)

                    GC.print(f.sizeStr,100,10)
                    GC.print(f.pixelStr,100,40)
                    GC.print(f.fileName,100,70)

                    GC.translate(800,0)
                end
            else
                FONT.set(80)
                GC.mStr("Congrats! No Duplicated Images Found!",800,420)
            end
        end
    else
        FONT.set(80)
        GC.mStr("MrZ's Duplicate Picture Finder",800,200)
        FONT.set(60)
        GC.mStr("Drag & drop files here",800,500-40*math.abs(math.sin(love.timer.getTime()*5)))
        FONT.set(30)
        GC.mStr("tab=change sorting rule  del=clear  enter=start filtering",800,700)
    end
end
SCN.add('manager',scene)
