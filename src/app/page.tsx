import {serverSupabase} from '@/lib/server';import GeraksiApp from '@/components/GeraksiApp';
export default async function Home(){const sb=await serverSupabase();const {data:{user}}=await sb.auth.getUser();return <GeraksiApp initialUser={user?{id:user.id,email:user.email||''}:null}/>}
