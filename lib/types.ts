export type Role = 'Buyer' | 'Seller' | 'Agent' | 'Admin';
export type PropertyStatus = 'For Sale' | 'For Rent' | 'Sold' | 'Rented' | 'Under Review' | 'Draft' | 'Paused' | 'Rejected';
export type Photo = number | string;
export interface Profile { id:string; name:string; role:Role; bio:string; city:string; email:string; phone:string; photo:Photo; cover:Photo; verified:boolean; }
export interface Property { id:string; ownerId:string; title:string; type:string; purpose:'Sale'|'Rent'; price:number; area:number; address:string; locality:string; city:string; state:string; pin:string; beds:number; baths:number; parking:number; floor:number; floors:number; furnishing:string; age:string; amenities:string[]; description:string; phone:string; status:PropertyStatus; available:string; photos:Photo[]; seller:string; sellerPhoto:Photo; sellerRole:string; verified:boolean; featured:boolean; demo:boolean; createdAt:string; likes:number; bookingAmount:number; }
export interface Comment { id:string; propertyId:string; userId:string; name:string; text:string; createdAt:string; }
export interface Message { id:string; text:string; senderId:string; createdAt:string; read:boolean; attachment?:string; }
export interface Conversation { id:string; propertyId:string; sellerId:string; seller:string; photo:Photo; messages:Message[]; archived:boolean; unread:number; }
export interface Notice { id:string; title:string; body:string; type:'message'|'listing'|'activity'|'payment'|'system'; read:boolean; createdAt:string; propertyId?:string; }
export interface Report { id:string; propertyId:string; reason:string; details:string; createdAt:string; status:'Open'|'Resolved'; reporterId:string; }
export interface Payment { id:string; propertyId:string; propertyTitle:string; buyer:string; seller:string; amount:number; fees:number; method:string; status:'Successful'|'Pending'|'Failed'|'Refunded'; transactionId:string; createdAt:string; }
export interface Filters { purpose:string; type:string; city:string; minPrice:string; maxPrice:string; minArea:string; maxArea:string; beds:string; baths:string; furnishing:string; parking:boolean; amenities:string[]; status:string; sort:string; }
export type Route = 'Home'|'Explore'|'Saved'|'Messages'|'Notifications'|'Payments'|'Profile'|'Dashboard'|'Admin'|'Settings';
