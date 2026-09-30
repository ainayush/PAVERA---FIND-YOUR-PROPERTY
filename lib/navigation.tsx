import React,{createContext,useContext} from 'react';
import {Route} from './types';
export type ModalName='details'|'gallery'|'sell'|'filters'|'comments'|'share'|'report'|'payment'|'auth'|'editProfile'|'seller'|'info'|'receipt';
export interface UiActions {navigate:(route:Route,param?:any)=>void;open:(name:ModalName,param?:any)=>void;close:()=>void;query:string;setQuery:(q:string)=>void;chat:(p:any)=>void;}
export const UIContext=createContext<UiActions>(null as any);
export const useUI=()=>useContext(UIContext);
