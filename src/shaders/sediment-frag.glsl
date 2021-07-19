#version 300 es
precision highp float;

uniform sampler2D readTerrain;//water and hight map R: hight map, G: water map, B: , A:
uniform sampler2D readVelocity;
uniform sampler2D readSediment;

uniform float u_SimRes;
uniform float u_PipeLen;
uniform float u_Ks;
uniform float u_Kc;
uniform float u_Kd;
uniform float u_timestep;

layout (location = 0) out vec4 writeTerrain;
layout (location = 1) out vec4 writeSediment;
layout (location = 2) out vec4 writeTerrainNormal;
layout (location = 3) out vec4 writeVelocity;





in vec2 fs_Pos;


vec3 calnor(vec2 uv){
  float eps = 1.f/u_SimRes;
  vec4 cur = texture(readTerrain,uv);
  vec4 r = texture(readTerrain,uv+vec2(eps,0.f));
  vec4 t = texture(readTerrain,uv+vec2(0.f,eps));
  vec4 b = texture(readTerrain,uv+vec2(0.f,-eps));
  vec4 l = texture(readTerrain,uv+vec2(-eps,0.f));

  vec4 rs = texture(readSediment,uv+vec2(eps,0.f));
  vec4 ts = texture(readSediment,uv+vec2(0.f,eps));
  vec4 bs = texture(readSediment,uv+vec2(0.f,-eps));
  vec4 ls = texture(readSediment,uv+vec2(-eps,0.f));


  //vec3 nor = vec3(l.x + l.y + ls.x - r.x - r.y - rs.x, 2.0, t.x + t.y + ts.x - b.x - b.y - bs.x);
  //vec3 nor = vec3(l.x + ls.x - r.x - rs.x, 2.0, t.x + ts.x - b.x - bs.x);
  vec3 nor = vec3(l.x - r.x , 2.0, t.x - b.x);
  nor = normalize(nor);
  return nor;
}

void main() {

  vec2 curuv = 0.5f*fs_Pos+0.5f;
  float div = 1.f/u_SimRes;
  float Kc = u_Kc;
  float Ks = u_Ks;
  float Kd = u_Kd;
  float alpha = 5.0;


  vec4 top = texture(readSediment,curuv+vec2(0.f,div));
  vec4 right = texture(readSediment,curuv+vec2(div,0.f));
  vec4 bottom = texture(readSediment,curuv+vec2(0.f,-div));
  vec4 left = texture(readSediment,curuv+vec2(-div,0.f));

  vec3 nor = calnor(curuv);
  float slopeSin;
  slopeSin = abs(sqrt(1.0 - nor.y*nor.y));
  //slopeSin = acos(dot(nor, vec3(0.0,1.0,0.0)));
  //slopeSin = abs(sin(acos(dot(nor, vec3(0.0, 1.0, 0.0)))));


  vec4 topvel = texture(readVelocity,curuv+vec2(0.f,div));
  vec4 rightvel = texture(readVelocity,curuv+vec2(div,0.f));
  vec4 bottomvel = texture(readVelocity,curuv+vec2(0.f,-div));
  vec4 leftvel = texture(readVelocity,curuv+vec2(-div,0.f));
  vec4 curvel = texture(readVelocity,curuv);

  float sumlen = length(topvel) + length(rightvel) + length(bottomvel) + length(leftvel);


//  if(length(curvel) > (sumlen/4.0)){ // make sure velocity are not too large
//      curvel *= (sumlen/4.0) / length(curvel);
//  }

  vec4 newVel = (topvel + rightvel + bottomvel + leftvel + alpha * curvel)/(4.0 + alpha);

  //newVel = mix(newVel,curvel,slopeSin);
  //newVel = curvel;

  vec4 curSediment = texture(readSediment,curuv);
  vec4 curTerrain = texture(readTerrain,curuv);

  //    t
  //
  // l  c--r
  //    | /
  //    b
//  float nordis = div*1.f;
//  vec4 nort = texture(readTerrain,curuv+vec2(0.f,nordis));
//  vec4 norr = texture(readTerrain,curuv+vec2(nordis,0.f));
//  vec4 norb = texture(readTerrain,curuv+vec2(0.f,-nordis));
//  vec4 norl = texture(readTerrain,curuv+vec2(-nordis,0.f));
//
//  vec3 dx = vec3(1.f,(norr.x + right.x - curTerrain.x - curSediment.x),0.f);
//  vec3 dy = vec3(1.f,(norr.x + right.x - norb.x - bottom.x),1.f);
//
//  vec3 nor = normalize(cross(dx,dy));




  float velo = length(texture(readVelocity,curuv).xy);
  velo = length(newVel.xy);
  float slope = max(0.01f, abs(slopeSin)) ;//max(0.05f,sqrt(1.f- nor.y * nor.y));
  float volC = 1.0 - exp(-curTerrain.y* (100.0));
  float sedicap = Kc*pow(slope,1.0)*pow(velo,1.0);// * pow(curTerrain.y,0.2) ;
  //sedicap *= pow(2.0,curTerrain.y);
  //sedicap = min(curTerrain.y * 2.0, sedicap); // TO DO : will the volume of water affect sediment capacity
  float lmax = 0.0f;
  float maxdepth = 1.8;
  if(curTerrain.y > maxdepth){ // max river bed depth
    lmax = 0.0f;
  }else{
    lmax = (max(maxdepth - curTerrain.y,0.0)/maxdepth);
  }


 //sedicap *= lmax;


  float cursedi = curSediment.x;
  float hight = curTerrain.x;
  float outsedi = curSediment.x;

  float water = curTerrain.y;

  if(sedicap>cursedi){
    float changesedi = (sedicap-cursedi)*Ks;
    //changesedi = min(changesedi, curTerrain.y);

      hight = hight - changesedi;
      // water = water + (sedicap-cursedi)*Ks;
      outsedi = outsedi + changesedi;

  }else {
    float changesedi = (cursedi-sedicap)*Kd;
    //changesedi = min(changesedi, curTerrain.y);
    hight = hight + changesedi;
    //water = water - (cursedi-sedicap)*Kd;
    outsedi = outsedi - changesedi;
  }


  writeTerrainNormal = vec4(vec3(slopeSin),1.f);
  writeSediment = vec4(outsedi,0.0f,0.0f,1.0f);
  writeTerrain = vec4(hight,curTerrain.y,curTerrain.z,curTerrain.w);
  writeVelocity = newVel;
}