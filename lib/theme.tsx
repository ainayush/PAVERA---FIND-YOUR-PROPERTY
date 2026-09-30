import React,{createContext,useContext,useState} from 'react';
import {useColorScheme} from 'react-native';
export const fonts={regular:'Manrope_400Regular',medium:'Manrope_500Medium',semi:'Manrope_600SemiBold',bold:'Manrope_700Bold',extra:'Manrope_800ExtraBold'};
const light={bg:'#F5F6F8',card:'#FFFFFF',text:'#20263D',muted:'#7A8192',line:'#EBEDF2',primary:'#4A55C7',navy:'#28316B',tint:'#EFF0FC',green:'#287D63',greenBg:'#EAF5EF',input:'#F7F8FA',danger:'#C44D58',white:'#FFFFFF'};
const dark={bg:'#141824',card:'#1D2232',text:'#EEF0FA',muted:'#A1A9BC',line:'#30374A',primary:'#A2AAFF',navy:'#8896F0',tint:'#303552',green:'#82D6B0',greenBg:'#243E36',input:'#242A3B',danger:'#FF95A0',white:'#FFFFFF'};
const ThemeContext=createContext({c:light,dark:false,mode:'light' as 'light'|'dark'|'system',setMode:(m:'light'|'dark'|'system')=>{}});
export function ThemeProvider({children}:{children:React.ReactNode}){const[mode,setMode]=useState<'light'|'dark'|'system'>('light');const system=useColorScheme();const isDark=mode==='dark'||(mode==='system'&&system==='dark');return <ThemeContext.Provider value={{c:isDark?dark:light,dark:isDark,mode,setMode}}>{children}</ThemeContext.Provider>}
export const useTheme=()=>useContext(ThemeContext);
