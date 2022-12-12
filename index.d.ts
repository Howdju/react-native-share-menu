
// The data shared by the user
export interface SharePreviewResponse {
  items: ShareDataItem[],
}

// The data provided by the module to a React Native app
export interface ShareResponse extends SharePreviewResponse {
  // iOS share extensions may optionally add extra data to the share response
  extraData?: Record<string, unknown>,
}

// Since we dynamically recognize the MIME type from file extensions, it
// could be any MIME type that has a corresponding extension.
type MimeType = string

// The possible roles the iOS module can provide.
//
// See ShareDataExtractor for details
type Role =
  // attributedTitle as text
  "title/text"
  // attributedTitle as HTML
  | "title/html"
  // attributedContentText as text
  | "content/text"
  // attributedContentText as HTML
  | "content/html"
  // A URL provider
  | "provider/url"
  // A URL that was also a file.
  | "provider/file-url"
  // An image provider that contained a URL
  | "provider/image/url"
  // An image provider that contained image data
  | "provider/image/data"
  // An text provider
  | "provider/text"
  // A data provider that contained a string
  | "provider/data/string"
  // A data provider that contained a URL
  | "provider/data/url"
  // A data provider that contained a JSON string corresponding to a Safari
  // Javascript preprocessing result.
  | "provider/data/javascript-preprocessing"
  // A property-list provider that contained a JSON string corresponding to a
  // Safari Javascript preprocessing result.
  | "provider/property-list/javascript-preprocessing"

// An item shared from a mobile app
export interface ShareDataItem {
  // The value of the shared item
  value: string,
  // The MIME type of the shared item. This can be a wildcard like img/* if
  // this share item is one of several that were shared with similar but non-
  // identical MIME types.
  mimeType: MimeType,
  // If the item is one of several representations for the same content, this
  // itemGroup will be the same for all items representing the same content.
  //
  // Example `"ItemGroup 2"`
  itemGroup?: string,
  // If the item is one of several representations for the same content, this
  // role identifies the source of the value.
  role?: Role,
}

export type ShareCallback = (response: ShareResponse) => void;
// The response is optional because there may not be an initial share.
export type InitialShareCallback = (response?: ShareResponse) => void;

export interface ShareListener {
  remove(): void;
}

// The main interface with the module
interface ShareMenu {
  getSharedText(callback: InitialShareCallback): void;
  getInitialShare(callback: InitialShareCallback): void;
  addNewShareListener(callback: ShareCallback): ShareListener;
  clearSharedText(): void;
}

// An interface for the module's iOS share extension
interface ShareMenuReactView {
  dismissExtension(error?: string): void;
  openApp(): void;
  // Share extensions may optionally add extraData to the ShareResponse
  continueInApp(extraData?: object): void;
  data(): Promise<SharePreviewResponse>;
}

export const ShareMenuReactView: ShareMenuReactView;
declare const ShareMenu: ShareMenu;
export default ShareMenu;
