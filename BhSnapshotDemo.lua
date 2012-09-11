--[[ 
BhSnapshotDemo.lua

A demonstration of the BhSnapshot.mm plugin for Gideros Studio
 
MIT License
Copyright (C) 2012. Andy Bower, Bowerhaus LLP

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

require "BhSnapshot"
require "gtween"
require "easing"

BhSnapshotDemo=Core.class(Sprite)

local FRAMESIZE=50

local function makeRectShape(x, y, width, height, color)
	local rect=Shape.new()
	rect:beginPath()
	rect:setFillStyle(Shape.SOLID, color)
	rect:moveTo(x, y)
	rect:lineTo(x+width, y)
	rect:lineTo(x+width, y+height)
	rect:lineTo(x, y+height)
	rect:lineTo(x, y)
	rect:endPath()
	return rect
end


function BhSnapshotDemo:onMouseDown(event)
	if self:hitTestPoint(event.x, event.y) then
		-- Create a photo frame-like border
		local bounds=self.image:bhGetBounds()
		self.frame=makeRectShape(
			bounds.left-FRAMESIZE,
			bounds.top-FRAMESIZE,
			bounds.width+FRAMESIZE*2,
			bounds.height+FRAMESIZE*2, 0xffffff)
		self:addChild(self.frame)
		
		-- Bring image in front of border
		self:addChild(self.image)
		
		-- Take a snapshot. This needs to be done after Gideros has had chance to assemble
		-- and display the frame buffer with the changes that we've made above.
		Timer.delayedCall(10, self.takeSnapshot, self)	
		
		event:stopPropagation()
	end
end

function BhSnapshotDemo:loadSnapshot(filename)	
	-- Throw the old image and load in the new photo and animate
	self.image:removeEventListener(Event.MOUSE_DOWN, self.onMouseDown, self)
	self.image:removeFromParent()
	self.frame:removeFromParent()
	self.bg:removeFromParent()
	
	self.bg=makeRectShape(0, 0, application:getContentWidth(), application:getContentHeight(), 0xefc870)
	self:addChild(self.bg)
	self:setPrompt("Poppy Comes to Stay")
	
	self.photo=Bitmap.new(Texture.new(filename))
	self.photo:setAnchorPoint(0.5, 0.5)
	--self.photo:setScale(0.5)
	self.photo:setPosition(2000, 2000)
	
	local cx, cy=stage:bhGetCenter()
	GTween.new(self.photo, 0.5, { x=cx, y=cy, rotation=1070})
	self:addChild(self.photo)

end

function BhSnapshotDemo:takeSnapshot()	
	-- Take a snapshot of the screen in the area of the image and surrounding frame and save
	-- first to the Saved Photos Album and second to a temporary file. We then reload from the
	-- temporary file, if only to show it can be done.
	
	Sound.new("Shutter.mp3"):play()
	local bounds=self.image:bhGetBounds()
	local scaleX, scaleY=application:getLogicalScaleX(), application:getLogicalScaleY()
--	print(scaleX, scaleY)
	local frameBounds={
		left=(bounds.left-FRAMESIZE)*scaleX, 
		top=(bounds.top-FRAMESIZE)*scaleY, 
		width=(bounds.width+FRAMESIZE*2)*scaleX, 
		height=(bounds.height+FRAMESIZE*2)*scaleY}
	
	BhSnapshot.snapshotToAlbum(frameBounds)
	
	local tmpFilename=BhSnapshot.snapshotToFile(256, frameBounds, nil, BhSnapshot.getPathForFile("|D|poppy.png"))
	print(tmpFilename)
	self:loadSnapshot(tmpFilename)
			
	-- Don't forget to remove the temporary image file
	os.remove(tmpFilename)
end

function BhSnapshotDemo:setPrompt(message)
	-- Set the prompt message and ensure it is centred and at top of z order
	self.prompt:setText(message)
	self.prompt:setPosition((application:getContentWidth()-self.prompt:getWidth())/2, application:getContentHeight()-100)
	self:addChild(self.prompt)
end

function BhSnapshotDemo:init()
	self.bg=makeRectShape(0, 0, application:getContentWidth(), application:getContentHeight(), 0xfc9fd6)
	self:addChild(self.bg)

	local image=Bitmap.new(Texture.new("Poppy.jpg"))
	image:setAnchorPoint(0.5, 0.5)
	image:setPosition(stage:bhGetCenter())
	self:addChild(image)
	self.image=image
	self.image:addEventListener(Event.MOUSE_DOWN, self.onMouseDown, self)
	
	self.prompt=TextField.new()
	self.prompt:setScale(2)
	self:setPrompt("Touch photo to create snapshot")

	self:addChild(self.prompt)
	stage:addChild(self)	
end