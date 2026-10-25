import type {Metadata} from 'next';import './globals.css';
export const metadata:Metadata={title:'GERAKSI | Gerakan Aksi Rendah Emisi',description:'Mobilitas rendah karbon mahasiswa dengan poin dan reward'};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="id"><body>{children}</body></html>}
