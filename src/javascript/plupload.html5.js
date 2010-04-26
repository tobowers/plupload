/**
 * plupload.html5.js
 *
 * Copyright 2009, Moxiecode Systems AB
 * Released under GPL License.
 *
 * License: http://www.plupload.com/license
 * Contributing: http://www.plupload.com/contributing
 */

// JSLint defined globals
/*global plupload:false, File:false, window:false, atob:false */

(function(plupload) {

	/**
	 * HMTL5 implementation. This runtime supports these features: dragdrop, jpgresize, pngresize.
	 *
	 * @static
	 * @class plupload.runtimes.Html5
	 * @extends plupload.Runtime
	 */
	plupload.runtimes.Html5 = plupload.addRuntime("html5", {
		/**
		 * Initializes the upload runtime.
		 *
		 * @method init
		 * @param {plupload.Uploader} uploader Uploader instance that needs to be initialized.
		 * @param {function} callback Callback to execute when the runtime initializes or fails to initialize. If it succeeds an object with a parameter name success will be set to true.
		 */
		init : function(uploader, callback) {
			var html5files = {}, dataAccessSupport;

			function addSelectedFiles(native_files) {
				var file, i, files = [], id;

				// Add the selected files to the file queue
				for (i = 0; i < native_files.length; i++) {
					file = native_files[i];

					// Store away gears blob internally
					id = plupload.guid();
					html5files[id] = file;

					// Expose id, name and size
					files.push(new plupload.File(id, file.fileName, file.fileSize));
				}

				// Trigger FilesAdded event if we added any
				if (files.length) {
					uploader.trigger("FilesAdded", files);
				}
			}

			function isSupported() {
				var xhr;

				if (window.XMLHttpRequest) {
					xhr = new XMLHttpRequest();

					return !!(xhr.sendAsBinary || xhr.upload);
				}

				return false;
			}

			// No HTML5 upload support
			if (!isSupported()) {
				callback({success : false});
				return;
			}

			uploader.bind("Init", function(up) {
				var inputContainer, mimes = [], i, y, filters = up.settings.filters, ext, type, container = document.body;

				// Create input container and insert it at an absolute position within the browse button
				inputContainer = document.createElement('div');
				inputContainer.id = up.id + '_html5_container';

				// Convert extensions to mime types list
				for (i = 0; i < filters.length; i++) {
					ext = filters[i].extensions.split(/,/);

					for (y = 0; y < ext.length; y++) {
						type = plupload.mimeTypes[ext[y]];

						if (type) {
							mimes.push(type);
						}
					}
				}

				plupload.extend(inputContainer.style, {
					position : 'absolute',
					background : uploader.settings.shim_bgcolor || 'transparent',
					width : '100px',
					height : '100px',
					overflow : 'hidden',
					zIndex : 99999,
					opacity : uploader.settings.shim_bgcolor ? '' : 0 // Force transparent if bgcolor is undefined
				});

				inputContainer.className = 'plupload html5';

				if (uploader.settings.container) {
					container = document.getElementById(uploader.settings.container);
					container.style.position = 'relative';
				}

				container.appendChild(inputContainer);

				// Insert the input inide the input container
				inputContainer.innerHTML = '<input id="' + uploader.id + '_html5" ' +
											'style="width:100%;" type="file" accept="' + mimes.join(',') + '" ' +
											(uploader.settings.multi_selection ? 'multiple="multiple"' : '') + ' />';

				document.getElementById(uploader.id + '_html5').onchange = function() {
					// Add the selected files from file input
					addSelectedFiles(this.files);

					// Clearing the value enables the user to select the same file again if they want to
					this.value = '';
				};
			});

			// Add drop handler
			uploader.bind("PostInit", function() {
				var dropElm = document.getElementById(uploader.settings.drop_element);

				if (dropElm) {
					// Block browser default drag over
					plupload.addEvent(dropElm, 'dragover', function(e) {
						e.preventDefault();
					});

					// Attach drop handler and grab files from Gears
					plupload.addEvent(dropElm, 'drop', function(e) {
						var dataTransfer = e.dataTransfer;

						// Add dropped files
						if (dataTransfer && dataTransfer.files) {
							addSelectedFiles(dataTransfer.files);
						}

						e.preventDefault();
					});
				}
			});

			uploader.bind("Refresh", function(up) {
				var browseButton, browsePos, browseSize;

				browseButton = document.getElementById(uploader.settings.browse_button);
				browsePos = plupload.getPos(browseButton, document.getElementById(up.settings.container));
				browseSize = plupload.getSize(browseButton);

				plupload.extend(document.getElementById(uploader.id + '_html5_container').style, {
					top : browsePos.y + 'px',
					left : browsePos.x + 'px',
					width : browseSize.w + 'px',
					height : browseSize.h + 'px'
				});
			});

			uploader.bind("UploadFile", function(up, file) {
				var xhr = new XMLHttpRequest(), upload = xhr.upload, nativeFile;

				// Sends the binary blob to server and multipart encodes it if needed this code will
				// only be executed on Gecko since it's currently the only browser that supports direct file access
				function sendBinaryBlob(blob) {
					xhr.sendAsBinary(blob);
				}

				// File upload finished
				if (file.status == plupload.DONE || file.status == plupload.FAILED || up.state == plupload.STOPPED) {
					return;
				}

				// Do we have upload progress support
				if (upload) {
					upload.onprogress = function(e) {
						file.loaded = e.loaded;
						up.trigger('UploadProgress', file);
					};
				}

				xhr.onreadystatechange = function() {
					var httpStatus = xhr.status;

					if (xhr.readyState == 4) {
						file.status = plupload.DONE;
						file.loaded = file.size;
						up.trigger('UploadProgress', file);
						up.trigger('FileUploaded', file, {
							response : xhr.responseText,
							status : httpStatus
						});

						// Response isn't 200 ok
						if (httpStatus != 200) {
							up.trigger('Error', {
								code : plupload.HTTP_ERROR,
								message : 'HTTP Error.',
								file : file,
								status : httpStatus
							});
						}
					}
				};
				
				var url = file.url || up.settings.url;
				var urlParams = plupload.extend({name : file.target_name || file.name}, up.settings.url_parameters);
				urlParams.offset = 0;
				xhr.open("post", plupload.buildUrl(url, urlParams), true);
				xhr.setRequestHeader('Content-Type', 'application/octet-stream');
				for (var key in up.settings.request_headers) {
					if (up.settings.request_headers.hasOwnProperty(key)) {
						xhr.setRequestHeader(key, up.settings.request_headers[key]);
					}
				}
				nativeFile = html5files[file.id]; 

				if (xhr.sendAsBinary) {
					sendBinaryBlob(nativeFile.getAsBinary());
				} else {
					xhr.send(nativeFile);
				}
			});

			// Do we have direct data access Gecko has it but WebKit doesn't yet
			dataAccessSupport = !!(File && File.prototype.getAsDataURL);

			uploader.features = {
				// Detect drag/drop file support by sniffing, will try to find a better way
				dragdrop : window.mozInnerScreenX !== undefined
			};

			callback({success : true});
		}
	});
})(plupload);
