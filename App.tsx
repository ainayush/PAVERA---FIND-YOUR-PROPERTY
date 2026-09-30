import React from 'react';
import { ActivityIndicator, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { useFonts } from 'expo-font';
import { Manrope_400Regular, Manrope_500Medium, Manrope_600SemiBold, Manrope_700Bold, Manrope_800ExtraBold } from '@expo-google-fonts/manrope';
import Ionicons from '@expo/vector-icons/Ionicons';
import { StoreProvider } from './lib/store';
import { ThemeProvider } from './lib/theme';
import Marketplace from './screens/Marketplace';

export default function App() {
  const [fontsLoaded, fontError] = useFonts({ ...Ionicons.font, Manrope_400Regular, Manrope_500Medium, Manrope_600SemiBold, Manrope_700Bold, Manrope_800ExtraBold });
  if (!fontsLoaded && !fontError) return <View style={{flex:1,alignItems:'center',justifyContent:'center',backgroundColor:'#f5f6f9'}}><ActivityIndicator color="#4954c6" /></View>;
  return <GestureHandlerRootView style={{ flex: 1 }}><SafeAreaProvider><ThemeProvider><StoreProvider><StatusBar style="auto" /><Marketplace /></StoreProvider></ThemeProvider></SafeAreaProvider></GestureHandlerRootView>;
} 
