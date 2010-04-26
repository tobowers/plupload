﻿/**
 * File.as
 *
 * Copyright 2009, Moxiecode Systems AB
 * Released under GPL License.
 *
 * License: http://www.plupload.com/license
 * Contributing: http://www.plupload.com/contributing
 */

package com.plupload {
	import flash.events.EventDispatcher;
	import flash.net.FileReference;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.HTTPStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.DataEvent;
	import flash.net.FileReferenceList;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLStream;
	import flash.net.URLVariables;
	import flash.utils.ByteArray;
	import flash.external.ExternalInterface;

	/**
	 * Container class for file references, this handles upload logic for individual files.
	 */
	public class File extends EventDispatcher {
		// Private fields
		private var _fileRef:FileReference, _cancelled:Boolean;
		private var _uploadUrl:String, _uploadPath:String;
		private var _id:String, _fileName:String, _size:uint;
		private var _chunkSize:int;
		private var _requestHeaders:Array, _currentOffset:int;

		/**
		 * Id property of file.
		 */
		public function get id():String {
			return this._id;
		}

		/**
		 * File name for the file.
		 */
		public function get fileName():String {
			return this._fileName;
		}

		/**
		 * File name for the file.
		 */
		public function set fileName(value:String):void {
			this._fileName = value;
		}

		/**
		 * File size property.
		 */
		public function get size():int {
			return this._size;
		}

		/**
		 * Constructs a new file object.
		 *
		 * @param id Unique indentifier for the file.
		 * @param file_ref File reference for the selected file.
		 */
		public function File(id:String, file_ref:FileReference) {
			this._id = id;
			this._fileRef = file_ref;
			this._size = file_ref.size;
			this._fileName = file_ref.name;
			Plupload.debug("File created: " + this._fileName);
		}

		/**
		 * Uploads a the file to the specified url. This method will upload it as a normal
		 * multipart file upload if the file size is smaller than the chunk size. But if the file is to
		 * large it will be chunked into multiple requests.
		 *
		 * @param url Url to upload the file to.
		 * @param settings Settings object.
		 */
		public function upload(url:String, settings:Object):void {
			var file:File = this;
			Plupload.debug("Uploading: " + this._fileName);
			
			// Setup internal vars
			this._uploadUrl = url;
			this._cancelled = false;
			this._requestHeaders = new Array();
			this._currentOffset = settings["starting_offset"] || 0;

			this._chunkSize = settings["chunk_size"];
			if (!this._chunkSize || (this._chunkSize == 0) || (this._chunkSize >= this._size)) {
				this._chunkSize = Math.ceil(file._size / 4)
			}
			
			if (settings["request_headers"]) {
				for (var key:String in settings["request_headers"]) {
					this._requestHeaders.push(new URLRequestHeader(key, settings["request_headers"][key]));
				}
			}

			// When file is loaded start uploading
			this._fileRef.addEventListener(Event.COMPLETE, function(e:Event):void {
				file.uploadNextChunk(this._currentOffset);
			});

			// File load IO error
			this._fileRef.addEventListener(IOErrorEvent.IO_ERROR, function(e:Event):void {
				this.dispatchEvent(e);
			});

			// Start loading local file
			this._fileRef.load();
		}

		// Private methods

		/**
		 * Uploads the next chunk or terminates the upload loop if all chunks are done.
		 */
		public function uploadNextChunk(offset:int = -1):Boolean {
			var req:URLRequest, fileData:ByteArray, chunkData:ByteArray;
			var urlStream:URLStream, url:String, file:File = this;
			var bytesToRead:int;
			
			if (offset == -1) {
				offset = this._currentOffset;
			}
			
			this._currentOffset = offset;
			Plupload.debug("Offset is: " + this._currentOffset.toString());
			
			// All chunks uploaded?
			if (this._currentOffset >= this._size) {
				Plupload.debug("returning false because cO: " + this._currentOffset.toString() + " > size: " + this._size);
				
				// Clean up memory
				this._fileRef.data.clear()
				this._fileRef = null;
				return false;
			}

			// Slice out a chunk
			chunkData = new ByteArray();
			fileData = this._fileRef.data;
			
			if (this._currentOffset + this._chunkSize > fileData.length) {
				bytesToRead = fileData.length - this._currentOffset
			} else {
				bytesToRead = this._chunkSize;
			}
			
			Plupload.debug("reading " + bytesToRead.toString() + " bytes");
			
			fileData.position = this._currentOffset;
			fileData.readBytes(chunkData, 0, bytesToRead);

			// Setup URL stream
			urlStream = new URLStream();

			// Wait for response and dispatch it
			urlStream.addEventListener(Event.COMPLETE, function(e:Event):void {
				var response:String, lastOffset:int;
				
				Plupload.debug("Uploaded chunk complete, firing complete events");
				
				lastOffset = file._currentOffset;
				file._currentOffset += file._chunkSize;
				
				response = urlStream.readUTFBytes(urlStream.bytesAvailable);
				
				// Clean up memory
				urlStream.close();
				chunkData.clear();
				
				// Fake UPLOAD_COMPLETE_DATA event
				var uploadChunkEvt:UploadChunkEvent = new UploadChunkEvent(
					UploadChunkEvent.UPLOAD_CHUNK_COMPLETE_DATA,
					false,
					false,
					response,
					lastOffset,
					file._chunkSize,
					file._size
				);

				dispatchEvent(uploadChunkEvt);


				// Fake progress event since Flash doesn't have a progress event for streaming data up to the server
				var pe:ProgressEvent = new ProgressEvent(ProgressEvent.PROGRESS, false, false, lastOffset, file._size);
				dispatchEvent(pe);
				
			});

			// Delegate upload IO errors
			urlStream.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent):void {
				file._currentOffset = file._size; // Cancel upload of all remaining chunks
				dispatchEvent(e);
			});

			// Delegate security errors
			urlStream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(e:SecurityErrorEvent):void {
				file._currentOffset = file._size; // Cancel upload of all remaining chunks
				dispatchEvent(e);
			});

			// Setup URL
			url = this._uploadUrl;
			
			if (url.indexOf('?') == -1) {
				url += '?';
			} else {
				url += '&';
			}
			url += "offset=" + this._currentOffset;

			Plupload.debug("sending to: " + url);
			

			// Setup request
			req = new URLRequest(url);
			req.method = URLRequestMethod.POST;
			req.requestHeaders = req.requestHeaders.concat(this._requestHeaders);

			req.requestHeaders.push(new URLRequestHeader("Content-Type", "application/octet-stream"));
			Plupload.debug("chunk data length is: " + chunkData.length.toString());
			req.data = chunkData;

			// Make request
			urlStream.load(req);
			
			return true;
		}
	}
}