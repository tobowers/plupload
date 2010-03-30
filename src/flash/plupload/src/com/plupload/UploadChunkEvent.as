/**
 * UploadChunkEvent.as
 *
 * Copyright 2009, Moxiecode Systems AB
 * Released under GPL License.
 *
 * License: http://www.plupload.com/license
 * Contributing: http://www.plupload.com/contributing
 */

package com.plupload {
	import flash.events.DataEvent;

	/**
	 * This class is used for uploads of chunks.
	 */
	public class UploadChunkEvent extends DataEvent {
		// Private fields
		private var _offset:int, _chunkSize:int, _fileSize:int;

		/**
		 * Chunk complete event name.
		 */
		public static const UPLOAD_CHUNK_COMPLETE_DATA:String = 'uploadchunk';

		/**
		 * offset property.
		 */
		public function get offset():int {
			return this._offset;
		}

		/**
		 * chunkSize property.
		 */
		public function get chunkSize():int {
			return this._chunkSize;
		}
		
		/**
		 * size property.
		 */
		public function get fileSize():int {
			return this._fileSize;
		}

		/**
		 * Main constructor for the UploadChunkEvent.
		 *
		 * @param	type
		 * @param	bubbles
		 * @param	cancelable
		 * @param	data
		 * @param	chunk
		 * @param	chunks
		 */
		function UploadChunkEvent(type:String, bubbles:Boolean, cancelable:Boolean, data:String, offset:int, chunkSize:int, fileSize:int) {
			super(type, bubbles, cancelable, data);
			this._offset = offset;
			this._chunkSize = chunkSize;
			this._fileSize = fileSize;
		}
	}
}